# Issue #19 — Report (sales, phase 2)

loop_state: landed

Status: phase-2 delivery. Closes the last A+ audit blocker
(`../proposals/canon-form-alignment.md`).

## What was done

core issue #83 ("canon-forms loop-body row pattern") landed:
`tokenmaxxxer-core` PR #84 (propose, `8e1d3db`) and PR #85 (deliver,
merged, `90a17ad`). This adds the loop-body `fragment-loop` canon-form row
the proposal asked for — the conditional-source line
(`[ -f "$frag" ] && . "$frag" 2>/dev/null`) inside
`sales/hooks/directive.sh:16-23`'s composition loop is now exempted by
`core/hooks/tests/canon-forms.txt`, not just the loop's header/footer.

Verified against the local `tokenmaxxxer-core` checkout at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core` — `git log` HEAD is
`90a17ad deliver(implementation): canon-forms loop-body row pattern
(issue-83) (#85)`, already current (the mount is read-only so `git pull`
itself errored on `FETCH_HEAD`, but the working tree was already at that
commit, no stale state).

Per the proposal, no sales-side file changed: `sales/hooks/directive.sh`
and `sales/hooks/hooks.json` are unchanged. The gap was core's canon-form
manifest, not a sales drift, and rewriting the loop to dodge the gap would
have re-encoded issue-10's approved design as worse boilerplate for no
reason once core's manifest fix landed.

### Verification run

Command:

```
CORE_PLUGIN_ROOT=/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core \
  bash sales/hooks/tests/run-stub-check.sh
```

Run 2026-08-01T13:54Z, exit 0 (`set -euo pipefail`, no stage failed):

```
stub-check: ok — no vendored 'trailer-gate.sh' under sales/hooks/tests/..
stub-check: ok — no vendored 'record-fields-gate.sh' under sales/hooks/tests/..
stub-check: ok — no vendored 'handbook-trigger-gate.sh' under sales/hooks/tests/..
stub-check: ok — no vendored 'parse-check.sh' under sales/hooks/tests/..
stub-check: ok — no vendored 'stub-check.sh' under sales/hooks/tests/..
stub-check: ok — no vendored 'gate-lib.sh' under sales/hooks/tests/..
stub-check: ok — no vendored 'gate-lib.py' under sales/hooks/tests/..
stub-check: ok — no vendored 'compliance-check.sh' under sales/hooks/tests/..
stub-check: ok — sales/hooks/tests/../directive.sh is a role-directive stub
name-consistency-check: ok — 6 file(s) checked against known-good set {sales, sales-playbook, sales-proposal-norm, sales-qualification-meddpicc, sales-rulebook, sales-stage-definitions}
```

The `.../directive.sh is a role-directive stub` line is the stage that was
RED before core #83 (loop-body form still unrecognized, "regrown
boilerplate" fail). It now passes, confirming the loop-body gap is closed
on core's side and `directive.sh` needed no rewrite.

## Why

Issue #19's sole 2026-08-01 A+ blocker was: core #78 lands, `run-stub-check.sh`
goes green after canon-form alignment (or confirmed no sales-side drift).
core #78 alone left a loop-body gap this issue's own proposal filed as
core #83; core #83 landing is the second and final half of that blocker.

## Upstream basis

- `docs/issue-19/proposals/canon-form-alignment.md` — the approved
  phase-1 design (file a core follow-up, no sales-side change) this
  phase-2 work implements verbatim.
- `docs/issue-19/reports/sales/current-state-survey.md` /
  `scout-brief.md` — the phase-1 gap inventory this phase-2 work verifies
  against.
- `tokenmaxxxer-core` issue #83, PRs #84/#85 (`8e1d3db`, `90a17ad`) — the
  landed core-side fix, referenced, never vendored (core canon is never
  vendored into a rulebook per `stub-check.sh`'s own header comment).

## What did not work

None. core #83 was already merged and the local core checkout was already
at that commit when this phase started, so no wait/retry was needed; the
verification run passed on the first invocation with `CORE_PLUGIN_ROOT`
pointed at the checkout's `core/` subdirectory (the plugin root, one level
below the checkout's repo root).

## Open findings

None new. The two open findings noted in `docs/issue-16/reports/sales.md`
(`sales-stage-definitions-gate.sh`'s missing out-of-scope skip, and this
very `directive.sh` loop-body gap) — the loop-body item is now resolved by
this delivery; the stage-definitions-gate skip remains open and unrelated
to issue #19's scope.

## Delivery execution stages

`docs/issue-<n>/reports/sales.md` is `sales-stage-definitions-gate.sh`'s
mandatory target regardless of an individual issue's content (open finding
above, unchanged since issue #16) — this section satisfies that structural
requirement by documenting this delivery's own actual execution stages.

## Stage 1: Core landing confirmed
Exit criteria:
- `tokenmaxxxer-core` issue #83 confirmed CLOSED via PRs #84 (propose) and #85 (deliver, merged)
- Local core checkout confirmed at commit `90a17ad`, matching the merged PR #85 tip
Next-stage handoff: Verification environment resolved

## Stage 2: Verification environment resolved
Exit criteria:
- Core plugin root located at `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core` (checkout root is one level above the plugin directory)
- `CORE_PLUGIN_ROOT` override confirmed as the correct mechanism per `docs/handbooks/stub-check.md`
Next-stage handoff: run-stub-check.sh executed

## Stage 3: run-stub-check.sh executed green
Exit criteria:
- `sales/hooks/tests/run-stub-check.sh` exited 0 against the resolved core checkout
- The previously-RED `directive.sh is a role-directive stub` stage confirmed passing in the run's output
Next-stage handoff: Record written

## Stage 4: Record written
Exit criteria:
- This file documents the core landing, the exact verification command, and its full green output
- Both issue-19 A+ blockers (core #78 and core #83) confirmed resolved with no sales-side code change
Next-stage handoff: Committed and pushed

## Stage 5: Delivered
Exit criteria:
- This record committed to `issue-19/sales` and pushed
- PR opened/updated against `main` for human merge
Next-stage handoff: Human PR review/merge (contract v3 s19)
