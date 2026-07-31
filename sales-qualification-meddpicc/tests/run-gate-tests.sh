#!/usr/bin/env bash
# Disposable-repo test harness for sales-qualification-meddpicc's PreToolUse gate.
# Builds a throwaway git repo, feeds stdin-JSON PreToolUse events to
# qualification-gate.sh, and asserts exit codes (0=allow, 2=deny).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$SCRIPT_DIR/../hooks/qualification-gate.sh"

pass=0
fail=0

setup_repo() {
  d="$(mktemp -d)"
  git -C "$d" init -q
  mkdir -p "$d/docs/issue-10/reports"
  echo "$d"
}

run_case() {
  name="$1"; expect="$2"; payload="$3"; extra_env="${4:-}"
  repo="$(setup_repo)"
  actual_payload="${payload//__ROOT__/$repo}"
  out="$(env $extra_env CLAUDE_PROJECT_DIR="$repo" bash -c "printf '%s' '$actual_payload' | '$GATE'" 2>&1)"
  rc=$?
  if [ "$rc" = "$expect" ]; then
    pass=$((pass+1))
    echo "PASS: $name (rc=$rc)"
  else
    fail=$((fail+1))
    echo "FAIL: $name (expected rc=$expect, got rc=$rc)"
    echo "  output: $out"
  fi
  rm -rf "$repo"
}

MEDDPICC_COMPLETE='# Sales Report\n\nframework_used: MEDDPICC\n\nMetrics: 20% cost reduction target\nEconomic Buyer: Jane Doe, VP Finance\nDecision Criteria: TCO and integration ease\nDecision Process: Committee review then CFO sign-off\nPaper Process: Legal review 2 weeks, procurement PO\nIdentify Pain: Manual reconciliation takes 40 hours/month\nChampion: Bob Smith, Ops Director\nCompetition: Incumbent vendor Acme Corp\n'

MEDDPICC_MISSING_PAPER='# Sales Report\n\nframework_used: MEDDPICC\n\nMetrics: 20% cost reduction target\nEconomic Buyer: Jane Doe, VP Finance\nDecision Criteria: TCO and integration ease\nDecision Process: Committee review then CFO sign-off\nIdentify Pain: Manual reconciliation takes 40 hours/month\nChampion: Bob Smith, Ops Director\nCompetition: Incumbent vendor Acme Corp\n'

MEDDPICC_ADVANCED_TBD_EB='# Sales Report\n\nframework_used: MEDDPICC\n\nMetrics: reduce cost\nEconomic Buyer: TBD\nDecision Criteria: unknown\nDecision Process: unknown\nPaper Process: unknown\nIdentify Pain: unknown\nChampion: Bob Smith\nCompetition: unknown\n\nThis opportunity has advanced past initial qualification.\n'

BANT_RECORD='# Sales Report\n\nframework_used: BANT\n\nBudget: 50000 approved\nAuthority: CFO signs off\nNeed: reduce manual work\nTiming: Q3 close target\n'

# 1. allow: complete MEDDPICC record
p1='{"tool_name":"Write","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/sales.md","content":"'"$MEDDPICC_COMPLETE"'"}}'
run_case "allow: complete MEDDPICC record" 0 "$p1"

# 2. deny: advancement claimed with TBD Economic Buyer
p2='{"tool_name":"Write","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/sales.md","content":"'"$MEDDPICC_ADVANCED_TBD_EB"'"}}'
run_case "deny: advancement with TBD Economic Buyer" 2 "$p2"

# 3. deny: MEDDPICC with Paper Process silently omitted
p3='{"tool_name":"Write","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/sales.md","content":"'"$MEDDPICC_MISSING_PAPER"'"}}'
run_case "deny: MEDDPICC missing Paper Process field" 2 "$p3"

# 4. allow: BANT record, no MEDDPICC-only fields required
p4='{"tool_name":"Write","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/sales.md","content":"'"$BANT_RECORD"'"}}'
run_case "allow: BANT record" 0 "$p4"

# 5. allow: kill switch set
p5='{"tool_name":"Write","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/sales.md","content":"'"$MEDDPICC_MISSING_PAPER"'"}}'
run_case "allow: kill switch set" 0 "$p5" "SALES_QUALIFICATION_GATE_OFF=1"

# 6. allow: foreign path
p6='{"tool_name":"Write","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/pricing.md","content":"'"$MEDDPICC_MISSING_PAPER"'"}}'
run_case "allow: foreign path (pricing.md)" 0 "$p6"

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
