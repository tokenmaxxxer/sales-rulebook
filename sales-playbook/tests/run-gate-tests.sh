#!/usr/bin/env bash
# Test harness for sales-playbook/hooks/playbook-gate.sh.
# Builds a disposable git repo, feeds stdin-JSON PreToolUse payloads to the
# gate, and checks the exit code (0 = allow, 2 = deny).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$SCRIPT_DIR/../hooks/playbook-gate.sh"

# Pre-flight core resolution per docs/specs/test-env-resolution.md
# (on-the-record, issue #551): outside the spawn env, SKIP instead of
# letting the gate's own source failure read as a misleading FAIL.
resolved="$(python3 "$SCRIPT_DIR/../../tests/lib/test_env_resolve.py" "$SCRIPT_DIR/../../core" "$SCRIPT_DIR/../../../tokenmaxxxer-core/core")"
rc=$?
[ "$rc" -eq 75 ] && exit 75
export CLAUDE_PLUGIN_ROOT_CORE="$resolved"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

REPO="$WORKDIR/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
mkdir -p "$REPO/docs/issue-10/reports"

pass=0
fail=0

run_case() {
  local desc="$1" expected_rc="$2" actual_payload="$3" extra_env="${4:-}" repo="${5:-$REPO}"
  local rc out
  out="$(env $extra_env CLAUDE_PROJECT_DIR="$repo" CLAUDE_ROLE=sales TG_PAYLOAD="$actual_payload" \
    bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
  rc=$?
  if [ "$rc" -eq "$expected_rc" ]; then
    echo "PASS: $desc"
    pass=$((pass+1))
  else
    echo "FAIL: $desc (expected rc=$expected_rc, got rc=$rc)"
    echo "  output: $out"
    fail=$((fail+1))
  fi
}

json_write_payload() {
  local file="$1" content="$2"
  python3 -c '
import json,sys
print(json.dumps({
    "tool_name": "Write",
    "tool_input": {"file_path": sys.argv[1], "content": sys.argv[2]}
}))
' "$file" "$content"
}

json_edit_payload() {
  local file="$1" old="$2" new="$3" replace_all="${4:-}"
  python3 -c '
import json,sys
ti = {"file_path": sys.argv[1], "old_string": sys.argv[2], "new_string": sys.argv[3]}
if len(sys.argv) > 4 and sys.argv[4] == "1":
    ti["replace_all"] = True
print(json.dumps({"tool_name": "Edit", "tool_input": ti}))
' "$file" "$old" "$new" "$replace_all"
}

json_multiedit_payload() {
  # args: file edit1_old edit1_new edit2_old edit2_new ...
  local file="$1"; shift
  python3 -c '
import json,sys
file = sys.argv[1]
rest = sys.argv[2:]
edits = []
for i in range(0, len(rest), 2):
    edits.append({"old_string": rest[i], "new_string": rest[i+1]})
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": file, "edits": edits}}))
' "$file" "$@"
}

FULL_GOOD_CONTENT='# Sales Playbook

## Process Overview
Standard sales process from lead to close.

## Qualification Framework
BANT-based qualification framework.

## ICP / Persona Summary
Our ICP is mid-market B2B SaaS buyers.

## Objection-Handling and Competitive Notes
Common objections and competitive notes are logged here.

## Metrics
Conversion rate and cycle length tracked here.

Full outbound copy and positioning language live in marketing'"'"'s asset library (see marketing-assets/messaging.md); reference by name, do not duplicate inline.
'

MISSING_METRICS_CONTENT='# Sales Playbook

## Process Overview
Standard sales process from lead to close.

## Qualification Framework
BANT-based qualification framework.

## ICP / Persona Summary
Our ICP is mid-market B2B SaaS buyers.

## Objection-Handling and Competitive Notes
Common objections and competitive notes are logged here.
'

INLINE_COPY_CONTENT='# Sales Playbook

## Process Overview
Standard sales process from lead to close.

## Qualification Framework
BANT-based qualification framework.

## ICP / Persona Summary
Our ICP is mid-market B2B SaaS buyers.

## Objection-Handling and Competitive Notes
Common objections and competitive notes are logged here.

## Metrics
Conversion rate and cycle length tracked here.

Email template: "Hi {{first_name}}, following up on our chat about..."
'

# 1. allow: all five sections present, no inline messaging copy
run_case "allow: all five sections present, marketing asset referenced" 0 \
  "$(json_write_payload "docs/issue-10/reports/sales.md" "$FULL_GOOD_CONTENT")"

# 2. deny: inline messaging-script content detected
run_case "deny: inline email template content detected" 2 \
  "$(json_write_payload "docs/issue-10/reports/sales.md" "$INLINE_COPY_CONTENT")"

# 3. deny: one of the five sections missing (Metrics)
run_case "deny: metrics section missing" 2 \
  "$(json_write_payload "docs/issue-10/reports/sales.md" "$MISSING_METRICS_CONTENT")"

# 4. allow: kill switch set (on-spelling bypass)
run_case "allow: kill switch set (SALES_PLAYBOOK_GATE_OFF=1)" 0 \
  "$(json_write_payload "docs/issue-10/reports/sales.md" "$MISSING_METRICS_CONTENT")" \
  "SALES_PLAYBOOK_GATE_OFF=1"

# 4b. deny: kill switch set to unrecognized garbage value -> gate stays active
run_case "deny: kill switch unrecognized value stays active (SALES_PLAYBOOK_GATE_OFF=typo)" 2 \
  "$(json_write_payload "docs/issue-10/reports/sales.md" "$MISSING_METRICS_CONTENT")" \
  "SALES_PLAYBOOK_GATE_OFF=typo"

# 5. allow: foreign path
run_case "allow: foreign path (pricing.md)" 0 \
  "$(json_write_payload "docs/issue-10/reports/pricing.md" "$MISSING_METRICS_CONTENT")"

# 6. Edit case: existing on-disk record fixed via Edit to become passing
mkdir -p "$REPO/docs/issue-11/reports"
printf '%s' "$MISSING_METRICS_CONTENT" > "$REPO/docs/issue-11/reports/sales.md"
EDIT_OLD='## Objection-Handling and Competitive Notes
Common objections and competitive notes are logged here.
'
EDIT_NEW='## Objection-Handling and Competitive Notes
Common objections and competitive notes are logged here.

## Metrics
Conversion rate and cycle length tracked here.
'
run_case "allow: Edit reconstruction fills missing Metrics section" 0 \
  "$(json_edit_payload "docs/issue-11/reports/sales.md" "$EDIT_OLD" "$EDIT_NEW")"

# 7. MultiEdit case: 2+ ordered edits, later depends on earlier
mkdir -p "$REPO/docs/issue-12/reports"
printf '%s' "$MISSING_METRICS_CONTENT" > "$REPO/docs/issue-12/reports/sales.md"
ME_OLD1='## Objection-Handling and Competitive Notes
Common objections and competitive notes are logged here.
'
ME_NEW1='## Objection-Handling and Competitive Notes
Common objections and competitive notes are logged here.

## Metrics
PLACEHOLDER
'
ME_OLD2='PLACEHOLDER'
ME_NEW2='Conversion rate and cycle length tracked here.'
run_case "allow: MultiEdit ordered edits (second depends on first)" 0 \
  "$(json_multiedit_payload "docs/issue-12/reports/sales.md" "$ME_OLD1" "$ME_NEW1" "$ME_OLD2" "$ME_NEW2")"

# 8. replace_all:true case — old_string occurs 2+ times, all must be replaced
mkdir -p "$REPO/docs/issue-14/reports"
RA_CONTENT='# Sales Playbook

## Process Overview
Standard sales process from lead to close.

## Qualification Framework
BANT-based qualification framework.

## ICP / Persona Summary
Our ICP is mid-market B2B SaaS buyers.

## Objection-Handling and Competitive Notes
Common objections and competitive notes are logged here.

## Metrics
PLACEHOLDER, still PLACEHOLDER pending finance sign-off.
'
printf '%s' "$RA_CONTENT" > "$REPO/docs/issue-14/reports/sales.md"
run_case "allow: replace_all true replaces every occurrence before check runs" 0 \
  "$(json_edit_payload "docs/issue-14/reports/sales.md" "PLACEHOLDER" "Conversion rate and cycle length tracked here" "1")"

# 9. Malformed-JSON case — invalid JSON must deny (rc=2)
run_case "deny: malformed JSON payload denies" 2 '{not valid json'

# 9b. Malformed-JSON case — valid JSON but not an object (bare array)
run_case "deny: bare-array JSON payload denies" 2 '[1,2,3]'

# 10. Absolute-path case — same result as relative equivalent
run_case "deny: absolute-path equivalent of missing-metrics case" 2 \
  "$(json_write_payload "$REPO/docs/issue-10/reports/sales.md" "$MISSING_METRICS_CONTENT")"

# 11. Single-quote-in-payload case — fixture value with a literal '
SQ_CONTENT='# Sales Playbook

## Process Overview
Standard sales process from lead to close. Champion: Bob'"'"'s team lead.

## Qualification Framework
BANT-based qualification framework.

## ICP / Persona Summary
Our ICP is mid-market B2B SaaS buyers.

## Objection-Handling and Competitive Notes
Common objections and competitive notes are logged here.

## Metrics
Conversion rate and cycle length tracked here.
'
run_case "allow: single-quote-in-payload survives harness" 0 \
  "$(json_write_payload "docs/issue-10/reports/sales.md" "$SQ_CONTENT")"

# 12. Structure-scoping case: required section name mentioned only in
# unrelated prose (not as an actual heading) must still deny as missing.
PROSE_ONLY_CONTENT='# Sales Playbook

## Process Overview
Standard sales process from lead to close. We track metrics informally
but there is no dedicated metrics write-up yet.

## Qualification Framework
BANT-based qualification framework.

## ICP / Persona Summary
Our ICP is mid-market B2B SaaS buyers.

## Objection-Handling and Competitive Notes
Common objections and competitive notes are logged here.
'
run_case "deny: 'metrics' mentioned only in prose, not as a heading, still missing" 2 \
  "$(json_write_payload "docs/issue-10/reports/sales.md" "$PROSE_ONLY_CONTENT")"

# 13. Marketing hand-off boundary is structure-scoped: a marketing keyword
# appearing only in an unrelated/quoted context outside the scoped section
# (e.g. inside the Process Overview section, not Objection-Handling/Metrics
# or the trailing hand-off note) must NOT trigger the deny.
SCOPE_SAFE_CONTENT='# Sales Playbook

## Process Overview
Standard sales process from lead to close. In a retro, a rep once joked
"this deal needed a whole email template just to explain itself" — no
actual template lives here, just an anecdote.

## Qualification Framework
BANT-based qualification framework.

## ICP / Persona Summary
Our ICP is mid-market B2B SaaS buyers.

## Objection-Handling and Competitive Notes
Common objections and competitive notes are logged here.

## Metrics
Conversion rate and cycle length tracked here.
'
run_case "allow: marketing keyword outside scoped sections does not trigger boundary deny" 0 \
  "$(json_write_payload "docs/issue-10/reports/sales.md" "$SCOPE_SAFE_CONTENT")"

# 14. missing-core: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere must deny, not allow
td="$(mktemp -d)"
out="$(printf '{"tool_name":"Write","tool_input":{"file_path":"docs/issue-1/reports/sales.md","content":"x"}}' \
    | env CLAUDE_ROLE=sales CLAUDE_PROJECT_DIR="$td" \
      CLAUDE_PLUGIN_ROOT_CORE="$td/no-such-core" \
      /bin/bash "$GATE" 2>&1)"
rc=$?
if [ "$rc" -eq 2 ]; then
  echo "PASS: playbook-gate.sh: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere denies (not silent-allow)"
  pass=$((pass+1))
else
  echo "FAIL: playbook-gate.sh: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere denies (not silent-allow) (expected rc=2, got rc=$rc)"
  echo "  output: $out"
  fail=$((fail+1))
fi
rm -rf "$td"

# 15. Bash-tool coverage: in-scope path via Bash command denies (cannot
# content-reconstruct a Bash write), out-of-scope Bash command allows.
td="$(mktemp -d)"; git init -q "$td"
bash_payload_in="$(python3 -c 'import json; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"cat > docs/issue-10/reports/sales.md <<EOF\nx\nEOF"}}))')"
out="$(env CLAUDE_PROJECT_DIR="$td" CLAUDE_ROLE=sales TG_PAYLOAD="$bash_payload_in" bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
rc=$?
if [ "$rc" -eq 2 ]; then
  echo "PASS: playbook-gate.sh: Bash write to in-scope path denies (cannot content-reconstruct)"
  pass=$((pass+1))
else
  echo "FAIL: playbook-gate.sh: Bash write to in-scope path denies (cannot content-reconstruct) (expected rc=2, got rc=$rc)"
  echo "  output: $out"
  fail=$((fail+1))
fi
bash_payload_out="$(python3 -c 'import json; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"cat > docs/issue-10/proposals/sales-thing.md <<EOF\nx\nEOF"}}))')"
out="$(env CLAUDE_PROJECT_DIR="$td" CLAUDE_ROLE=sales TG_PAYLOAD="$bash_payload_out" bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "PASS: playbook-gate.sh: Bash write to out-of-scope path allows"
  pass=$((pass+1))
else
  echo "FAIL: playbook-gate.sh: Bash write to out-of-scope path allows (expected rc=0, got rc=$rc)"
  echo "  output: $out"
  fail=$((fail+1))
fi
rm -rf "$td"

echo
echo "----------------------------------------"
echo "Passed: $pass, Failed: $fail"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
