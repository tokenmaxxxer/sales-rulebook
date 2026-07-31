#!/usr/bin/env bash
# Test harness for sales-playbook/hooks/playbook-gate.sh.
# Builds a disposable git repo, feeds stdin-JSON PreToolUse payloads to the
# gate, and checks the exit code (0 = allow, 2 = deny).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$SCRIPT_DIR/../hooks/playbook-gate.sh"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

REPO="$WORKDIR/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
mkdir -p "$REPO/docs/issue-10/reports"

pass=0
fail=0

run_case() {
  local desc="$1" expected_rc="$2" payload="$3"
  local rc
  actual_out="$(CLAUDE_PROJECT_DIR="$REPO" CLAUDE_ROLE=sales bash "$GATE" <<<"$payload" 2>&1)"
  rc=$?
  if [ "$rc" -eq "$expected_rc" ]; then
    echo "PASS: $desc"
    pass=$((pass+1))
  else
    echo "FAIL: $desc (expected rc=$expected_rc, got rc=$rc)"
    echo "  output: $actual_out"
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

# 4. allow: kill switch set
actual_out="$(CLAUDE_PROJECT_DIR="$REPO" CLAUDE_ROLE=sales SALES_PLAYBOOK_GATE_OFF=1 bash "$GATE" <<<"$(json_write_payload "docs/issue-10/reports/sales.md" "$MISSING_METRICS_CONTENT")" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "PASS: allow: kill switch set (SALES_PLAYBOOK_GATE_OFF=1)"
  pass=$((pass+1))
else
  echo "FAIL: allow: kill switch set (expected rc=0, got rc=$rc)"
  echo "  output: $actual_out"
  fail=$((fail+1))
fi

# 5. allow: foreign path
run_case "allow: foreign path (pricing.md)" 0 \
  "$(json_write_payload "docs/issue-10/reports/pricing.md" "$MISSING_METRICS_CONTENT")"

echo
echo "----------------------------------------"
echo "Passed: $pass, Failed: $fail"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
