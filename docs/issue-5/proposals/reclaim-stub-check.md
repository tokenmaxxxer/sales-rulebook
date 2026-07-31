---
subject: issue-5
role: implementation
loop_state: open
---

# Proposal — reclaim vendored stub-check.sh copy

Per survey.md: this rulebook holds one vendored core-canon copy
(`sales/hooks/tests/stub-check.sh`, manifest-listed in core's
`canon-manifest.txt`) and no `hooks.json` registration for it. Following
core's documented reclaim procedure
(`tokenmaxxxer-core:docs/issue-69/reports/implementation/reclaim-21-copies.md`)
and invocation model
(`tokenmaxxxer-core:docs/handbooks/role-gates-tests.md`).

## Phase-2 execution plan

1. Delete `sales/hooks/tests/stub-check.sh`.
2. Add a thin `sales/hooks/tests/run-stub-check.sh` wrapper containing
   only the canon invocation line:

       "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" "$(dirname "$0")/.."

   This gives the rulebook a stable entry point instead of the bare
   `bash sales/hooks/tests/stub-check.sh sales` command a prior PR
   description used ad hoc.
3. Confirm the `${CLAUDE_PLUGIN_ROOT}`-sibling resolution against this
   repo's actual install layout (core's doc flags this as unverified
   outside a same-checkout sibling layout) before treating the wrapper as
   final; adjust `CORE_PLUGIN_ROOT` fallback if this repo's install
   doesn't place `core/` as a literal plugin sibling.
4. Run the wrapper; record PASS/FAIL and full output in
   `docs/issue-5/reports/implementation.md`.
5. Update `README.md:38-40` to describe `run-stub-check.sh` as a
   core-canon reference call, not a vendored copy.
6. No `hooks.json` change needed — confirmed no existing entry.

## Open question for approver

None blocking — the invocation shape is fully specified by core canon.
Only the sibling-path fallback (step 3) may need a one-line adjustment
once run for real, which phase 2 will do and record.
