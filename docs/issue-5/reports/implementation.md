---
subject: issue-5
role: implementation
loop_state: landed
---

# Phase-2 record — stub-check.sh reclaim

## What was done

1. Deleted `sales/hooks/tests/stub-check.sh` (vendored copy of core canon).
2. Added `sales/hooks/tests/run-stub-check.sh` — thin wrapper containing only
   the core canon invocation line:

       "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" "$(dirname "$0")/.."

3. Confirmed (survey + re-confirmed here) no `stub-check` entry exists in
   `sales/hooks/hooks.json` — no hooks.json change was needed.
4. Updated `README.md` layout entry to describe `run-stub-check.sh` as a
   core-canon reference call, not a vendored copy.
5. Ran the core reference invocation against this repo and recorded the
   PASS result below.

## Why

Core issue #69 canon (`docs/handbooks/canon-scripts.md`,
`docs/handbooks/role-gates-tests.md` in `tokenmaxxxer-core`) mandates that
`stub-check.sh` and other manifest-listed canon scripts be invoked by
reference from a role's rulebook, never vendored as a second copy, instead
of leaving the prior vendored copy in place. This rulebook's
`sales/hooks/tests/stub-check.sh` (added in PR #4 / commit b41179b) was
exactly such a vendored copy and had to be reclaimed per issue #5.

## Upstream basis

- `tokenmaxxxer-core:docs/handbooks/canon-scripts.md` — "canon scripts are
  referenced, never copied."
- `tokenmaxxxer-core:docs/handbooks/role-gates-tests.md` ("Canon invocation
  from a rulebook") — sanctioned invocation shape used verbatim in
  `run-stub-check.sh` above; the doc flags the sibling-resolution
  expression as unverified outside a same-checkout sibling layout and asks
  each rollout to confirm it, which is done below.
- `tokenmaxxxer-core:docs/issue-69/reports/implementation/reclaim-21-copies.md`
  — the 4-step reclaim procedure this rulebook's reclaim is one instance
  of.
- Commit b41179b (this repo) — the PR #4 commit that originally vendored
  `stub-check.sh`, now reverted here.
- Approved via issue comment `APPROVE issue-5/implementation` (single-account
  mode, JiwonJung94, an approvers.md account), opening phase 2 per contract
  v3 s19.

## Sibling-path fallback confirmation

This checkout has no `core/` installed as a literal sibling of `sales/`, so
the default `$CLAUDE_PLUGIN_ROOT/../core` fallback could not be exercised
as-is in this environment. Verified instead by pointing `CORE_PLUGIN_ROOT`
explicitly at a core checkout (`tokenmaxxxer-core` issue-69 implementation
worktree, `core/hooks/tests/stub-check.sh`) via the wrapper's documented
override — the sanctioned escape hatch for installs where the sibling
assumption doesn't hold, not a deviation from canon. A real marketplace
install (`core/` as a literal plugin sibling) should confirm the bare
default form separately; that confirmation is outside what this session's
environment can exercise.

## Run and result

Command:

    CORE_PLUGIN_ROOT=<core-checkout>/core bash sales/hooks/tests/run-stub-check.sh

Output:

    stub-check: ok — no vendored 'trailer-gate.sh' under sales/hooks/tests/..
    stub-check: ok — no vendored 'record-fields-gate.sh' under sales/hooks/tests/..
    stub-check: ok — no vendored 'handbook-trigger-gate.sh' under sales/hooks/tests/..
    stub-check: ok — no vendored 'parse-check.sh' under sales/hooks/tests/..
    stub-check: ok — no vendored 'stub-check.sh' under sales/hooks/tests/..
    stub-check: ok — sales/hooks/tests/../directive.sh is a role-directive stub

Exit code: 0 — **PASS**.

## Open findings

None blocking issue #5's closure. One item worth flagging for core/other
roles: the default `$CLAUDE_PLUGIN_ROOT/../core` sibling-resolution path in
`role-gates-tests.md` remains unverified against a real marketplace
install layout across rollouts so far (this repo's dev checkout isn't
one) — core's own doc already tracks this as an open item; this issue does
not close it, only confirms the override path works.
