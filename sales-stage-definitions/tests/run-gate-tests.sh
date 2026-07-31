#!/usr/bin/env bash
# Disposable-repo test harness for sales-stage-definitions-gate.sh.
# Builds a scratch git repo, feeds stdin-JSON PreToolUse events, checks exit codes.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$SCRIPT_DIR/../hooks/stage-definitions-gate.sh"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/sd-gate-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

git -C "$WORKDIR" init -q
mkdir -p "$WORKDIR/docs/issue-10/reports"

pass=0
fail=0

run_case() {
  local name="$1" expected_rc="$2" json="$3"
  local out rc
  out="$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$WORKDIR" CLAUDE_ROLE="sales" "$GATE" 2>&1)"
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

GOOD_CONTENT='Stage Definitions\nstage_count: 6\nexit_criteria_present: yes for all stages\nStage 1: Contract signed\nStage 2: Budget confirmed'
BAD_VERB_CONTENT='Stage Definitions\nstage_count: 6\nexit_criteria_present: yes\nStage 1: had a call with buyer'
BAD_RANGE_CONTENT='Stage Definitions\nstage_count: 3\nexit_criteria_present: yes'
MISSING_COUNT_CONTENT='Stage Definitions\nexit_criteria_present: yes'

json_write() {
  local path="$1" content="$2"
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))
' "$path" "$content"
}

run_case "allow: in-range stage_count with exit criteria, no rep-activity verbs" 0 \
  "$(json_write docs/issue-10/reports/sales.md "$GOOD_CONTENT")"

run_case "deny: rep-activity-verb stage name present" 2 \
  "$(json_write docs/issue-10/reports/sales.md "$BAD_VERB_CONTENT")"

run_case "deny: stage_count out of range" 2 \
  "$(json_write docs/issue-10/reports/sales.md "$BAD_RANGE_CONTENT")"

run_case "deny: stage_count missing" 2 \
  "$(json_write docs/issue-10/reports/sales.md "$MISSING_COUNT_CONTENT")"

json_kill="$(json_write docs/issue-10/reports/sales.md "$BAD_RANGE_CONTENT")"
out="$(printf '%s' "$json_kill" | CLAUDE_PROJECT_DIR="$WORKDIR" CLAUDE_ROLE="sales" SALES_STAGE_DEFINITIONS_GATE_OFF=1 "$GATE" 2>&1)"
rc=$?
if [ "$rc" = 0 ]; then
  echo "PASS: allow: kill switch set"
  pass=$((pass+1))
else
  echo "FAIL: allow: kill switch set (expected rc=0, got rc=$rc)"
  echo "  output: $out"
  fail=$((fail+1))
fi

run_case "allow: foreign path (pricing.md)" 0 \
  "$(json_write docs/issue-10/reports/pricing.md "$BAD_RANGE_CONTENT")"

echo
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
