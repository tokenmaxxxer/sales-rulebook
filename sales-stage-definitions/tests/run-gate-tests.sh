#!/usr/bin/env bash
# Disposable-repo test harness for sales-stage-definitions-gate.sh.
# Builds a scratch git repo, feeds stdin-JSON PreToolUse events, checks exit codes.
#
# Requires CLAUDE_PLUGIN_ROOT_CORE to point at a checkout of core containing
# hooks/lib/gate-lib.sh and hooks/lib/gate-lib.py (issue-72's gate-house lib).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$SCRIPT_DIR/../hooks/stage-definitions-gate.sh"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/sd-gate-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

git -C "$WORKDIR" init -q
mkdir -p "$WORKDIR/docs/issue-10/reports"

pass=0
fail=0

# run_case name expected_rc json [extra_env]
run_case() {
  local name="$1" expected_rc="$2" json="$3" extra_env="${4:-}"
  local out rc repo="$WORKDIR"
  out="$(env $extra_env CLAUDE_PROJECT_DIR="$repo" CLAUDE_ROLE="sales" CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-}" TG_PAYLOAD="$json" bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
  rc=$?
  if [ "$rc" = "$expected_rc" ]; then
    echo "PASS: $name"
    pass=$((pass+1))
  else
    echo "FAIL: $name (expected rc=$expected_rc, got rc=$rc)"
    echo "  output: $out"
    fail=$((fail+1))
  fi
}

good_stage() {
  # $1=num $2=name $3=crit1 $4=crit2 $5=handoff
  printf '## Stage %s: %s\nExit criteria:\n- %s\n- %s\nNext-stage handoff: %s\n\n' "$1" "$2" "$3" "$4" "$5"
}

GOOD_CONTENT="$(cat <<'EOF'
# Stage Definitions

## Stage 1: Needs identified
Exit criteria:
- Buyer documented pain points
- Buyer confirmed priority in writing
Next-stage handoff: Champion identified

## Stage 2: Champion identified
Exit criteria:
- Champion confirmed role internally
- Champion agreed to advocate
Next-stage handoff: Business case approved

## Stage 3: Business case approved
Exit criteria:
- Business case approved by exec sponsor
- ROI model validated by finance
Next-stage handoff: Technical validation completed

## Stage 4: Technical validation completed
Exit criteria:
- POC completed successfully
- Technical stakeholders signed off
Next-stage handoff: Budget confirmed

## Stage 5: Budget confirmed
Exit criteria:
- Budget approved by finance
- Budget confirmed in writing
Next-stage handoff: Contract signed

## Stage 6: Contract signed
Exit criteria:
- Buyer signed the contract
- Legal approved the terms
Next-stage handoff: Onboarding
EOF
)"

BAD_VERB_CONTENT="$(cat <<'EOF'
## Stage 1: had a call with buyer
Exit criteria:
- Buyer confirmed pain points
- Buyer confirmed priority
Next-stage handoff: Stage 2

## Stage 2: Champion identified
Exit criteria:
- Champion confirmed role
- Champion agreed to advocate
Next-stage handoff: Stage 3

## Stage 3: Business case approved
Exit criteria:
- Business case approved
- ROI validated
Next-stage handoff: Stage 4

## Stage 4: Technical validation completed
Exit criteria:
- POC completed
- Stakeholders signed off
Next-stage handoff: Stage 5

## Stage 5: Budget confirmed
Exit criteria:
- Budget approved
- Budget confirmed
Next-stage handoff: Contract signed
EOF
)"

# 3 stages only -> out of range
BAD_RANGE_CONTENT="$(cat <<'EOF'
## Stage 1: Needs identified
Exit criteria:
- Buyer documented pain points
- Buyer confirmed priority
Next-stage handoff: Champion identified

## Stage 2: Champion identified
Exit criteria:
- Champion confirmed role
- Champion agreed to advocate
Next-stage handoff: Business case approved

## Stage 3: Business case approved
Exit criteria:
- Business case approved
- ROI validated
Next-stage handoff: Onboarding
EOF
)"

# 5 stages, but Stage 1 only has 1 exit criterion
INSUFFICIENT_CRITERIA_CONTENT="$(cat <<'EOF'
## Stage 1: Needs identified
Exit criteria:
- Buyer documented pain points
Next-stage handoff: Champion identified

## Stage 2: Champion identified
Exit criteria:
- Champion confirmed role
- Champion agreed to advocate
Next-stage handoff: Business case approved

## Stage 3: Business case approved
Exit criteria:
- Business case approved
- ROI validated
Next-stage handoff: Technical validation completed

## Stage 4: Technical validation completed
Exit criteria:
- POC completed
- Stakeholders signed off
Next-stage handoff: Budget confirmed

## Stage 5: Budget confirmed
Exit criteria:
- Budget approved
- Budget confirmed
Next-stage handoff: Contract signed
EOF
)"

# 5 stages, but Stage 1 handoff is a placeholder
MISSING_HANDOFF_CONTENT="$(cat <<'EOF'
## Stage 1: Needs identified
Exit criteria:
- Buyer documented pain points
- Buyer confirmed priority
Next-stage handoff: TBD

## Stage 2: Champion identified
Exit criteria:
- Champion confirmed role
- Champion agreed to advocate
Next-stage handoff: Business case approved

## Stage 3: Business case approved
Exit criteria:
- Business case approved
- ROI validated
Next-stage handoff: Technical validation completed

## Stage 4: Technical validation completed
Exit criteria:
- POC completed
- Stakeholders signed off
Next-stage handoff: Budget confirmed

## Stage 5: Budget confirmed
Exit criteria:
- Budget approved
- Budget confirmed
Next-stage handoff: Contract signed
EOF
)"

# stage-related keyword mentioned only in unrelated prose, no actual
# headings at all -> must still deny (missing/no stage sections)
PROSE_ONLY_CONTENT="$(cat <<'EOF'
# Sales Notes

We discussed stage definitions informally in the kickoff call, but nothing
has been finalized. exit_criteria_present and stage_count were mentioned in
passing during the meeting, along with a next-stage handoff idea, but none
of this is an actual stage section with real headings.
EOF
)"

# adjacency-tolerant: label and value split across lines, irregular spacing
ADJACENCY_CONTENT="$(cat <<'EOF'
## Stage 1: Needs identified
Exit criteria:
-   Buyer documented pain points
-   Buyer confirmed priority in writing
Next-stage handoff:
    Champion identified

## Stage 2: Champion identified
Exit criteria:
- Champion confirmed role internally
- Champion agreed to advocate
Next-stage handoff: Business case approved

## Stage 3: Business case approved
Exit criteria:
- Business case approved by exec sponsor
- ROI model validated by finance
Next-stage handoff: Technical validation completed

## Stage 4: Technical validation completed
Exit criteria:
- POC completed successfully
- Technical stakeholders signed off
Next-stage handoff: Budget confirmed

## Stage 5: Budget confirmed
Exit criteria:
- Budget approved by finance
- Budget confirmed in writing
Next-stage handoff: Contract signed
EOF
)"

json_write() {
  local path="$1" content="$2"
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))
' "$path" "$content"
}

json_edit() {
  local path="$1" old="$2" new="$3"
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":sys.argv[2],"new_string":sys.argv[3]}}))
' "$path" "$old" "$new"
}

json_edit_ra() {
  local path="$1" old="$2" new="$3"
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":sys.argv[2],"new_string":sys.argv[3],"replace_all":True}}))
' "$path" "$old" "$new"
}

json_multiedit() {
  local path="$1"; shift
  python3 -c '
import json,sys
path=sys.argv[1]
pairs=sys.argv[2:]
edits=[{"old_string":pairs[i],"new_string":pairs[i+1]} for i in range(0,len(pairs),2)]
print(json.dumps({"tool_name":"MultiEdit","tool_input":{"file_path":path,"edits":edits}}))
' "$path" "$@"
}

run_case "allow: 6 stages, each with >=2 exit criteria and named handoff" 0 \
  "$(json_write docs/issue-10/reports/sales.md "$GOOD_CONTENT")"

run_case "deny: rep-activity-verb stage name present" 2 \
  "$(json_write docs/issue-10/reports/sales.md "$BAD_VERB_CONTENT")"

run_case "deny: stage_count out of range (3 stages)" 2 \
  "$(json_write docs/issue-10/reports/sales.md "$BAD_RANGE_CONTENT")"

run_case "deny: insufficient exit criteria (1 of 2 required)" 2 \
  "$(json_write docs/issue-10/reports/sales.md "$INSUFFICIENT_CRITERIA_CONTENT")"

run_case "deny: placeholder next-stage handoff (TBD)" 2 \
  "$(json_write docs/issue-10/reports/sales.md "$MISSING_HANDOFF_CONTENT")"

run_case "deny: structure-scoping — stage keywords only in unrelated prose, no real sections" 2 \
  "$(json_write docs/issue-10/reports/sales.md "$PROSE_ONLY_CONTENT")"

run_case "allow: adjacency-tolerant handoff label/value split across lines" 0 \
  "$(json_write docs/issue-10/reports/sales.md "$ADJACENCY_CONTENT")"

# --- issue-22 spec-alignment: Deal state loop_state vocabulary. ---
for word in qualifying negotiating landed economic-buyer-undeclared deal-unreachable; do
  run_case "allow: Deal state: $word (spec vocab word)" 0 \
    "$(json_write docs/issue-10/reports/sales.md "$GOOD_CONTENT

Deal state: $word
")"
done

run_case "deny: Deal state: stale/unlisted word" 2 \
  "$(json_write docs/issue-10/reports/sales.md "$GOOD_CONTENT

Deal state: closed-won
")"

run_case "allow: no Deal state label declared at all" 0 \
  "$(json_write docs/issue-10/reports/sales.md "$GOOD_CONTENT")"

# --- Edit case: seed an on-disk passing doc, then Edit a bad detail into
# a still-passing doc via old_string/new_string. ---
mkdir -p "$WORKDIR/docs/issue-11/reports"
printf '%s' "$GOOD_CONTENT" > "$WORKDIR/docs/issue-11/reports/sales.md"
run_case "allow: Edit against existing on-disk record producing a passing doc" 0 \
  "$(json_edit docs/issue-11/reports/sales.md "Next-stage handoff: Onboarding" "Next-stage handoff: Renewal kickoff")"

# --- MultiEdit case: 2+ ordered edits, later depends on earlier. ---
mkdir -p "$WORKDIR/docs/issue-12/reports"
printf '%s' "$GOOD_CONTENT" > "$WORKDIR/docs/issue-12/reports/sales.md"
run_case "allow: MultiEdit with 2+ ordered edits, later depends on earlier" 0 \
  "$(json_multiedit docs/issue-12/reports/sales.md \
      "Next-stage handoff: Onboarding" "Next-stage handoff: STEP_A" \
      "Next-stage handoff: STEP_A" "Next-stage handoff: Renewal kickoff")"

# --- replace_all:true case: old_string occurs 2+ times, all replaced. ---
# "Champion" occurs 3 times in GOOD_CONTENT (heading, criterion, handoff
# reference) without touching the structural "Exit criteria"/"Next-stage
# handoff" labels the semantic check keys off of.
mkdir -p "$WORKDIR/docs/issue-13/reports"
printf '%s' "$GOOD_CONTENT" > "$WORKDIR/docs/issue-13/reports/sales.md"
run_case "allow: replace_all true replaces all occurrences" 0 \
  "$(json_edit_ra docs/issue-13/reports/sales.md "Champion" "CHAMPION")"

# --- Malformed-JSON case: invalid JSON / bare array -> deny rc=2. ---
run_case "deny: malformed JSON payload" 2 '{not valid json'
run_case "deny: bare JSON array payload" 2 '[1,2,3]'

# --- Kill-switch cases. ---
json_kill="$(json_write docs/issue-10/reports/sales.md "$BAD_RANGE_CONTENT")"
out="$(CLAUDE_PROJECT_DIR="$WORKDIR" CLAUDE_ROLE="sales" CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-}" SALES_STAGE_DEFINITIONS_GATE_OFF=1 TG_PAYLOAD="$json_kill" bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
rc=$?
if [ "$rc" = 0 ]; then
  echo "PASS: allow: kill switch on-spelling (=1) bypasses gate"
  pass=$((pass+1))
else
  echo "FAIL: allow: kill switch on-spelling (=1) bypasses gate (expected rc=0, got rc=$rc)"
  echo "  output: $out"
  fail=$((fail+1))
fi

out="$(CLAUDE_PROJECT_DIR="$WORKDIR" CLAUDE_ROLE="sales" CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-}" SALES_STAGE_DEFINITIONS_GATE_OFF=typo TG_PAYLOAD="$json_kill" bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
rc=$?
if [ "$rc" = 2 ]; then
  echo "PASS: deny: kill switch unrecognized value (typo) stays ACTIVE"
  pass=$((pass+1))
else
  echo "FAIL: deny: kill switch unrecognized value (typo) stays ACTIVE (expected rc=2, got rc=$rc)"
  echo "  output: $out"
  fail=$((fail+1))
fi

run_case "allow: foreign path (pricing.md)" 0 \
  "$(json_write docs/issue-10/reports/pricing.md "$BAD_RANGE_CONTENT")"

# --- Absolute-path case: same result as relative equivalent. ---
run_case "deny: absolute-path equivalent of stage_count-out-of-range case" 2 \
  "$(json_write "$WORKDIR/docs/issue-10/reports/sales.md" "$BAD_RANGE_CONTENT")"

# --- Single-quote-in-payload case: fixture value with a literal quote char. ---
apost="'"
QUOTE_CONTENT="${GOOD_CONTENT/Needs identified/Needs identified (buyer${apost}s own words)}"
run_case "allow: payload containing a literal single quote survives the harness" 0 \
  "$(json_write docs/issue-10/reports/sales.md "$QUOTE_CONTENT")"

# missing-core: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere must deny, not allow
td="$(mktemp -d)"
out="$(printf '{"tool_name":"Write","tool_input":{"file_path":"docs/issue-1/reports/sales.md","content":"x"}}' \
    | env CLAUDE_ROLE=sales CLAUDE_PROJECT_DIR="$td" \
      CLAUDE_PLUGIN_ROOT_CORE="$td/no-such-core" \
      /bin/bash "$GATE" 2>&1)"
rc=$?
got=$([ $rc = 0 ] && echo allow || { [ $rc = 2 ] && echo deny || echo "exit-$rc"; })
if [ "$got" = "deny" ]; then
  echo "PASS: stage-definitions-gate.sh: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere denies (not silent-allow)"
  pass=$((pass+1))
else
  echo "FAIL: stage-definitions-gate.sh: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere denies (not silent-allow) (expected deny, got $got)"
  echo "  output: $out"
  fail=$((fail+1))
fi
rm -rf "$td"

# Bash-tool coverage: in-scope path via Bash command denies (cannot
# content-reconstruct a Bash write), out-of-scope Bash command allows.
td="$(mktemp -d)"; git init -q "$td"
bash_payload_in="$(python3 -c 'import json; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"cat > docs/issue-10/reports/sales.md <<EOF\nx\nEOF"}}))')"
out="$(env CLAUDE_PROJECT_DIR="$td" CLAUDE_ROLE=sales CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-}" TG_PAYLOAD="$bash_payload_in" bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
rc=$?
case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
if [ "$got" = "deny" ]; then
  echo "PASS: stage-definitions-gate.sh: Bash write to in-scope path denies (cannot content-reconstruct)"
  pass=$((pass+1))
else
  echo "FAIL: stage-definitions-gate.sh: Bash write to in-scope path denies (cannot content-reconstruct) (expected deny, got $got)"
  echo "  output: $out"
  fail=$((fail+1))
fi
bash_payload_out="$(python3 -c 'import json; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"cat > docs/issue-10/proposals/sales-thing.md <<EOF\nx\nEOF"}}))')"
out="$(env CLAUDE_PROJECT_DIR="$td" CLAUDE_ROLE=sales CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-}" TG_PAYLOAD="$bash_payload_out" bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
rc=$?
case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
if [ "$got" = "allow" ]; then
  echo "PASS: stage-definitions-gate.sh: Bash write to out-of-scope path allows"
  pass=$((pass+1))
else
  echo "FAIL: stage-definitions-gate.sh: Bash write to out-of-scope path allows (expected allow, got $got)"
  echo "  output: $out"
  fail=$((fail+1))
fi
rm -rf "$td"

echo
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
