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

# Payload passed via an exported var, read inside double-quoted bash -c, so
# a literal single quote in the payload does not corrupt the command
# (issue-13 phase-2 harness fix — the prior single-quoted
# `bash -c "... '$actual_payload' ..."` construction broke on a literal `'`).
run_case() {
  name="$1"; expect="$2"; payload="$3"; extra_env="${4:-}"
  repo="$(setup_repo)"
  actual_payload="${payload//__ROOT__/$repo}"
  out="$(env $extra_env CLAUDE_PROJECT_DIR="$repo" TG_PAYLOAD="$actual_payload" \
    bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
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

# 5. allow: kill switch set (recognized on-spelling)
p5='{"tool_name":"Write","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/sales.md","content":"'"$MEDDPICC_MISSING_PAPER"'"}}'
run_case "allow: kill switch set (=1)" 0 "$p5" "SALES_QUALIFICATION_GATE_OFF=1"

# 6. allow: foreign path
p6='{"tool_name":"Write","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/pricing.md","content":"'"$MEDDPICC_MISSING_PAPER"'"}}'
run_case "allow: foreign path (pricing.md)" 0 "$p6"

# 7. Edit case: old_string/new_string against an existing on-disk record
#    producing a passing doc — asserts reconstructed-not-original is read.
setup_edit_repo() {
  repo="$(setup_repo)"
  printf '%b' "$MEDDPICC_MISSING_PAPER" > "$repo/docs/issue-10/reports/sales.md"
  echo "$repo"
}
edit_repo="$(setup_edit_repo)"
p7='{"tool_name":"Edit","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/sales.md","old_string":"Identify Pain:","new_string":"Paper Process: Legal review 2 weeks, procurement PO\nIdentify Pain:"}}'
actual_p7="${p7//__ROOT__/$edit_repo}"
out7="$(env CLAUDE_PROJECT_DIR="$edit_repo" TG_PAYLOAD="$actual_p7" bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
rc7=$?
if [ "$rc7" = "0" ]; then
  pass=$((pass+1)); echo "PASS: Edit case reconstructs content (rc=$rc7)"
else
  fail=$((fail+1)); echo "FAIL: Edit case reconstructs content (expected rc=0, got rc=$rc7)"; echo "  output: $out7"
fi
rm -rf "$edit_repo"

# 8. MultiEdit case: 2+ ordered edits, a later edit depends on an earlier one's result.
multi_repo="$(setup_edit_repo)"
p8='{"tool_name":"MultiEdit","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/sales.md","edits":[{"old_string":"Identify Pain:","new_string":"PLACEHOLDER_PAPER\nIdentify Pain:"},{"old_string":"PLACEHOLDER_PAPER","new_string":"Paper Process: Legal review 2 weeks, procurement PO"}]}}'
actual_p8="${p8//__ROOT__/$multi_repo}"
out8="$(env CLAUDE_PROJECT_DIR="$multi_repo" TG_PAYLOAD="$actual_p8" bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
rc8=$?
if [ "$rc8" = "0" ]; then
  pass=$((pass+1)); echo "PASS: MultiEdit ordered-dependent edits (rc=$rc8)"
else
  fail=$((fail+1)); echo "FAIL: MultiEdit ordered-dependent edits (expected rc=0, got rc=$rc8)"; echo "  output: $out8"
fi
rm -rf "$multi_repo"

# 9. replace_all:true case — old_string occurs 2+ times, asserting every
#    occurrence is replaced before the check runs.
ra_repo="$(setup_repo)"
RA_DOC='# Sales Report\n\nframework_used: MEDDPICC\n\nMetrics: XXX\nEconomic Buyer: XXX\nDecision Criteria: XXX\nDecision Process: XXX\nPaper Process: XXX\nIdentify Pain: XXX\nChampion: XXX\nCompetition: XXX\n'
printf '%b' "$RA_DOC" > "$ra_repo/docs/issue-10/reports/sales.md"
p9='{"tool_name":"Edit","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/sales.md","old_string":"XXX","new_string":"value provided here","replace_all":true}}'
actual_p9="${p9//__ROOT__/$ra_repo}"
out9="$(env CLAUDE_PROJECT_DIR="$ra_repo" TG_PAYLOAD="$actual_p9" bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
rc9=$?
if [ "$rc9" = "0" ]; then
  pass=$((pass+1)); echo "PASS: replace_all:true replaces every occurrence (rc=$rc9)"
else
  fail=$((fail+1)); echo "FAIL: replace_all:true replaces every occurrence (expected rc=0, got rc=$rc9)"; echo "  output: $out9"
fi
rm -rf "$ra_repo"

# 10. Malformed-JSON case (not valid JSON) — must deny rc=2.
p10='not valid json at all'
run_case "deny: malformed (non-JSON) payload" 2 "$p10"

# 10b. Malformed-JSON case: valid JSON but a bare array, not an object — must deny rc=2.
p10b='["Write", {"file_path":"x"}]'
run_case "deny: valid-JSON-but-non-object payload (bare array)" 2 "$p10b"

# 11. Kill-switch unrecognized-value case — gate must stay ACTIVE (not bypassed).
p11='{"tool_name":"Write","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/sales.md","content":"'"$MEDDPICC_MISSING_PAPER"'"}}'
run_case "deny: kill switch unrecognized value stays active (=typo)" 2 "$p11" "SALES_QUALIFICATION_GATE_OFF=typo"

# 12. Absolute-path case — file_path given as an absolute path, resolved
#     against CLAUDE_PROJECT_DIR, asserting same result as relative-path equivalent.
abs_repo="$(setup_repo)"
p12='{"tool_name":"Write","tool_input":{"file_path":"'"$abs_repo"'/docs/issue-10/reports/sales.md","content":"'"$MEDDPICC_COMPLETE"'"}}'
out12="$(env CLAUDE_PROJECT_DIR="$abs_repo" TG_PAYLOAD="$p12" bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
rc12=$?
if [ "$rc12" = "0" ]; then
  pass=$((pass+1)); echo "PASS: absolute-path file_path resolves same as relative (rc=$rc12)"
else
  fail=$((fail+1)); echo "FAIL: absolute-path file_path resolves same as relative (expected rc=0, got rc=$rc12)"; echo "  output: $out12"
fi
rm -rf "$abs_repo"

# 13. Single-quote-in-payload case — a fixture whose field value contains a
#     literal ' — asserting the harness itself survives (regression test
#     for the harness fix).
SQ_DOC="# Sales Report\n\nframework_used: MEDDPICC\n\nMetrics: 20% cost reduction target\nEconomic Buyer: Jane Doe, VP Finance\nDecision Criteria: TCO and integration ease\nDecision Process: Committee review then CFO sign-off\nPaper Process: Legal review 2 weeks, procurement PO\nIdentify Pain: Manual reconciliation takes 40 hours/month\nChampion: Bob's team lead\nCompetition: Incumbent vendor Acme Corp\n"
p13='{"tool_name":"Write","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/sales.md","content":"'"$SQ_DOC"'"}}'
run_case "allow: single-quote-in-payload (Bob's team lead) survives harness" 0 "$p13"

# 14. Section-scoping case — field name mentioned only in unrelated prose
#     outside the qualification section must still deny as missing.
SCOPE_DOC='# Sales Report\n\n## Qualification\n\nframework_used: MEDDPICC\n\nMetrics: 20% cost reduction target\nEconomic Buyer: Jane Doe, VP Finance\nDecision Criteria: TCO and integration ease\nDecision Process: Committee review then CFO sign-off\nPaper Process: Legal review 2 weeks, procurement PO\nIdentify Pain: Manual reconciliation takes 40 hours/month\nChampion: Bob Smith, Ops Director\n\n## Unrelated Notes\n\nWe discussed competition in the broader market at a conference last week.\n'
p14='{"tool_name":"Write","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/sales.md","content":"'"$SCOPE_DOC"'"}}'
run_case "deny: competition mentioned only outside scoped section" 2 "$p14"

# 15. Adjacency-tolerant TBD case — TBD on the line after its label, must
#     still deny as TBD (advancement claimed with EB TBD-on-next-line).
NEXTLINE_TBD='# Sales Report\n\nframework_used: MEDDPICC\n\nMetrics: reduce cost\nEconomic Buyer:\nTBD\nDecision Criteria: unknown\nDecision Process: unknown\nPaper Process: unknown\nIdentify Pain: unknown\nChampion: Bob Smith\nCompetition: unknown\n\nThis opportunity has advanced past initial qualification.\n'
p15='{"tool_name":"Write","tool_input":{"file_path":"__ROOT__/docs/issue-10/reports/sales.md","content":"'"$NEXTLINE_TBD"'"}}'
run_case "deny: adjacency-tolerant TBD (label then value on next line)" 2 "$p15"

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
