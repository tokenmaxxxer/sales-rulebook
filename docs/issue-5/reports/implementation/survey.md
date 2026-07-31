---
subject: issue-5
role: implementation
loop_state: open
---

# Phase-1 survey — stub-check.sh copy reclaim

Scout: skipped. Pure reclaim of a documented core canon (core issue #69);
no open design decision — canon-scripts.md and role-gates-tests.md in
`tokenmaxxxer-core` already specify the exact target invocation.

## Current state in this repo

- `sales/hooks/tests/stub-check.sh` (89 lines) — vendored copy of core's
  `core/hooks/tests/stub-check.sh`, added in PR #4 (issue-2 phase 2,
  commit b41179b) to run a one-off manual PASS check. It is on core's
  `canon-manifest.txt`, so it is itself a manifest-listed canon file and
  must not be vendored.
- `sales/hooks/hooks.json` — no `stub-check` entry. It only registers
  `SessionStart` → `directive.sh`. Nothing to remove there; issue text's
  "if hooks.json registration exists, remove it" does not apply to this
  repo.
- No test-harness entry point exists in `sales/` that invokes
  `stub-check.sh` — it was run manually per PR #4's test plan
  (`bash sales/hooks/tests/stub-check.sh sales`). There is no
  `run-tests.sh` or similar to update.
- `README.md:38-40` documents the file as "vendored copy ... run against
  `sales/`" — this line must change once the file is deleted.

## Core canon (tokenmaxxxer-core, confirmed)

- `docs/handbooks/canon-scripts.md`: "Canon scripts are referenced, never
  copied" — any `core/hooks/` or `core/hooks/tests/` file is invoked via a
  path resolved against core's own install root; a rulebook tree never
  holds a second copy.
- `docs/handbooks/role-gates-tests.md` ("Canon invocation from a
  rulebook"): the sanctioned invocation shape is

      "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" "$(dirname "$0")/.."

  first arg stays the rulebook-relative scan target; the binary is never
  copied. The doc flags that the exact sibling-resolution expression is
  unverified against the real marketplace install layout (core's own test
  run is same-checkout siblings) and should be confirmed against one pilot
  rulebook before wide rollout.
- `docs/issue-69/reports/implementation/reclaim-21-copies.md`: the
  documented 4-step reclaim procedure (enumerate → delete-and-reference →
  verify per-repo → batch with issue-63/issue-66) that this rulebook's
  reclaim is one instance of. Execution status there: "Not started."

## Gap

`sales/` has no test-harness script to hold the reference invocation line
— only a manual `bash ... stub-check.sh sales` step in a past PR
description. The proposal must decide where that invocation line now
lives (a small new `sales/hooks/tests/run-stub-check.sh` wrapper vs.
documenting the bare command in README/record). This is the one open
question phase 2 execution resolves.
