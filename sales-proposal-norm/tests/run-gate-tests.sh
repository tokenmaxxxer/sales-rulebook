#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-30s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-30s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

run() { # want name path content extra_env
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$3")"
  pf="$(mktemp)"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" > "$pf"
  env CLAUDE_PROJECT_DIR="$td" CLAUDE_ROLE=sales ${5:-} /bin/bash "$HOOKS/proposal-norm-gate.sh" < "$pf" >/dev/null 2>&1
  rc=$?; rm -f "$pf"; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

COMPLETE='Status: phase-1-only.
## Scope
Scoped against the current-state survey.
## Guiding principle
One sentence.
## Per-item breakdown
Item one: does X.
## Adoption rationale
Sourced from Y.
## Plugin-reflection plan
Will touch Z.'

MISSING_RATIONALE='Status: phase-1-only.
## Scope
Scoped against the current-state survey.
## Guiding principle
One sentence.
## Per-item breakdown
Item one.
## Plugin-reflection plan
Will touch Z.'

run allow all-six-sections     "docs/issue-10/proposals/sales-thing.md" "$COMPLETE"
run deny  missing-rationale    "docs/issue-10/proposals/sales-thing.md" "$MISSING_RATIONALE"
run allow foreign-path         "docs/issue-10/proposals/pricing-thing.md" "nothing at all"
run allow kill-switch-set      "docs/issue-10/proposals/sales-thing.md" "$MISSING_RATIONALE" "SALES_PROPOSAL_NORM_GATE_OFF=1"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
