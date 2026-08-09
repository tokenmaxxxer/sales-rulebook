---
code_under_review:
  - tests/lib/test_env_resolve.py
  - sales-proposal-norm/tests/run-gate-tests.sh
  - sales-stage-definitions/tests/run-gate-tests.sh
  - sales-qualification-meddpicc/tests/run-gate-tests.sh
  - sales-playbook/tests/run-gate-tests.sh
  - sales/hooks/tests/run-stub-check.sh
  - docs/handbooks/stub-check.md
  - docs/handbooks/test-env-resolution.md
type: fix
breaking: false
verdict: pass
loop_state: landed
---

# Implementation record — issue #25

## What was done
Adopted the canonical test-env resolution convention
(`docs/specs/test-env-resolution.md`, on-the-record issue #551) across
this rulebook's gate-test scripts, per the approved proposal
`docs/issue-25/proposals/2026-08-09-test-env-resolution.md`:

- Vendored `tests/lib/test_env_resolve.py`, a verbatim copy of the
  on-the-record reference resolver, header-commented as sourced from
  `docs/specs/test-env-resolution.md` (issue #551) and not to be
  modified independently of that source.
- Added a pre-flight resolution call to the top of each of the four
  `*/tests/run-gate-tests.sh` scripts (proposal-norm,
  stage-definitions, qualification-meddpicc, playbook): invokes the
  vendored resolver with sibling candidates anchored on the script's
  own directory (`$HERE/../../core`,
  `$HERE/../../../tokenmaxxxer-core/core`); on exit 75 the script exits
  75 immediately (no fixtures run); on success it exports
  `CLAUDE_PLUGIN_ROOT_CORE` to the resolved path so the gate's own
  existing internal resolution finds it, then the existing fixture loop
  (including each script's `missing-core` fixture) runs unchanged.
- Added the same pre-flight call to `sales/hooks/tests/run-stub-check.sh`
  before it execs core's `stub-check.sh`; on exit 75 it exits 75 instead
  of letting the exec fail with a raw shell "No such file or directory".
- Each modified script carries a comment citing
  `docs/specs/test-env-resolution.md`.

## Why
Per the issue: these gate-test scripts assumed the spawn-session
environment and failed misleadingly (blanket FAIL / raw shell error)
outside it. Basis: `docs/issue-25/proposals/2026-08-09-test-env-resolution.md`
and its survey `docs/issue-25/reports/implementation/survey.md`.
Vendoring the reference resolver verbatim (rather than a bash
reimplementation) reuses the on-the-record convention's own test
coverage and matches the shape `architecture-rulebook` (issue #22)
already adopted for the same convention.

## Upstream
Basis: `docs/issue-25/proposals/2026-08-09-test-env-resolution.md`
(approved via issue comment `APPROVE issue-25/implementation` by
JiwonJung94, listed in `docs/specs/approvers.md`, single-account mode).
Reference source: `docs/specs/test-env-resolution.md` (on-the-record,
issue #551).

## Verification run
- Outside spawn env (`CLAUDE_PLUGIN_ROOT_CORE` unset, no reachable
  sibling core from this checkout's location): all five modified
  scripts printed exactly `SKIP: core plugin unreachable —
  unverifiable outside spawn env` on stderr and exited 75 — zero FAIL
  lines, zero raw shell errors.
- With `CLAUDE_PLUGIN_ROOT_CORE` set to a reachable core checkout (this
  session's spawn env): `sales-proposal-norm` (17/17 pass),
  `sales-stage-definitions` (27/27 pass), `sales-playbook` (18/18
  pass), and `sales/hooks/tests/run-stub-check.sh` all pass unchanged
  vs. pre-change baseline. `sales-qualification-meddpicc` shows 14
  passed / 8 failed — verified via `git stash` that this exact
  14-passed/8-failed result is the **pre-existing baseline**
  (unrelated to this change): the change does not touch that gate's
  logic or fixtures, and the resolution-dependent fixtures inside that
  same run (`CLAUDE_PLUGIN_ROOT_CORE pointed-nowhere`, Bash-coverage
  in-scope/out-of-scope) all pass.
- `grep -rl test-env-resolution` across all five modified script
  directories plus `tests/lib` finds every modified script and the
  vendored resolver.
- Post-hunt-fix re-check of `sales/hooks/tests/run-stub-check.sh`:
  `CORE_PLUGIN_ROOT` set to a reachable core -> runs the check, exit 0;
  unset, no reachable sibling -> SKIP, exit 75; spawn env
  (`CLAUDE_PLUGIN_ROOT_CORE` set, no `CORE_PLUGIN_ROOT`) -> runs the
  check, exit 0 — matches pre-change behavior in all three cases.

## Doc placement
- `docs/issue-25/reports/implementation.md` (this file) — the record.
- No env var, config key, new dependency, migration, or setup step was
  introduced — nothing to add to a handbook.
- No library/format choice over a named alternative beyond what the
  proposal's `## Rationale` already recorded — no new
  `docs/issue-25/decisions/` entry needed.

## What did not work
None.

## Hunt (before-landing)
Dispatched warrant-hunter, stance index 4 (write-set-cannot-carry-work),
diff 44 lines / 5 files -> 120s cap, default tier. Record:
`docs/reports/2026-08-09-hunt-test-env-resolution.md`.

FINDING: the pre-flight resolver in `sales/hooks/tests/run-stub-check.sh`
ignored the documented `CORE_PLUGIN_ROOT` override
(`docs/handbooks/stub-check.md`), silently SKIPping instead of running
the check when a caller set it — a regression against a previously
working, on-record workflow (issue-5, issue-19). Fixed in the same
commit: `CORE_PLUGIN_ROOT`, when set, is used directly and wins before
the resolver runs at all (matching prior `${CORE_PLUGIN_ROOT:-...}`
semantics exactly); the resolver only runs as the fallback when it is
unset. Re-verified: override path runs the check (exit 0), unset+
unreachable path still SKIPs (exit 75), spawn-env path still runs (exit
0).

closed_checks:
- CORE_PLUGIN_ROOT override still works after adding the pre-flight
  resolver (code_under_review: 6c392bb) — re-verified manually,
  see Verification run below.

## Open findings
- `sales-qualification-meddpicc/tests/run-gate-tests.sh` has 8
  pre-existing failing fixtures when core IS reachable (adjacency-
  tolerant label/value parsing, malformed-JSON payload handling, bare-
  array payload handling, kill-switch-typo handling, prose-mention
  scoping) — confirmed via `git stash` to predate this change and to be
  unrelated to test-env resolution. This is a real gate defect per the
  issue's own empty-state clause ("if a script's failure is a REAL
  defect, record it as a finding — do not mask it with SKIP") and is
  out of scope for this issue (proposal's Out of scope: "Any change
  inside the gate hooks themselves").

## Next steps
Commit this record together with the code changes, push, and open the
PR (`Closes #25`); update `loop_state` to `landed` and fill
`code_under_review` with the landing commit sha once pushed.

## Resolution path
File a follow-up issue against
`sales-qualification-meddpicc/hooks/qualification-gate.sh` for the 8
pre-existing fixture failures noted under Open findings.
