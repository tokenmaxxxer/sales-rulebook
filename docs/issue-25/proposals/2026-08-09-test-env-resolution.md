---
status: proposed
files:
  - tests/lib/test_env_resolve.py
  - sales-proposal-norm/tests/run-gate-tests.sh
  - sales-stage-definitions/tests/run-gate-tests.sh
  - sales-qualification-meddpicc/tests/run-gate-tests.sh
  - sales-playbook/tests/run-gate-tests.sh
  - sales/hooks/tests/run-stub-check.sh
---

## Request
Adopt the canonical test-env resolution convention landed at
on-the-record `docs/specs/test-env-resolution.md` (issue #551) across
this rulebook's gate-test scripts: outside the spawn env (no
`CLAUDE_PLUGIN_ROOT_CORE`, no reachable sibling core checkout), every
script that depends on core should exit with the convention's SKIP
contract (explicit message, distinct exit code 75) instead of the
misleading blanket FAILs / raw shell errors it produces today.
Assertions that run when core IS reachable stay unchanged.

## Constraints
- Do not weaken any assertion that runs when core is reachable.
- SKIP exit code 75 must never collide with a gate's own pass (0) /
  fail (1) / deny (2), nor with `run-gate-tests.sh`'s own `fail=1`
  aggregation exit.
- No network fetch for core — local resolution only
  (`$CLAUDE_PLUGIN_ROOT_CORE` or caller-supplied sibling candidates).
- Each `missing-core` fixture (`CLAUDE_PLUGIN_ROOT_CORE` deliberately
  set to a bogus path) exercises the *gate's own* fail-closed behavior
  and must keep passing unchanged — it is orthogonal to the new
  pre-flight check (resolution order step 1: env var wins even broken).
- Modified scripts reference `test-env-resolution` (issue's grep check).
- `sales/hooks/tests/name-consistency-check.sh` and
  `sales/hooks/tests/run-name-consistency-tests.sh` never resolve core
  — the convention's own known exception — and are left untouched.

## Rationale
Per the survey (`docs/issue-25/reports/implementation/survey.md`),
three shapes were available:

1. **Vendor the on-the-record reference resolver
   (`gates/test_env_resolve.py`) verbatim under
   `tests/lib/test_env_resolve.py`, invoked as a CLI from each script** —
   chosen. This is the convention doc's own documented "Bash test
   runner" adoption path, reuses the already-tested reference resolver
   (`gates/test_test_env_resolve.py` covers the env-var hit, sibling
   hit, empty-stub non-match, and SKIP path), and matches the shape
   `architecture-rulebook` (issue #22) already adopted for the same
   convention — keeping cross-repo consumers consistent instead of each
   inventing its own variant.
2. **Re-implement the resolution order directly in bash** (inline per
   script, or one shared sourced `tests/lib/resolve-core.sh`) —
   rejected. It would drop the reference module's own test coverage and
   produce a second, unreviewed bash port of logic the convention
   already verified once — precisely the "consumer hand-rolls its own"
   problem the convention exists to end.
3. **Fix only the `run-gate-tests.sh` scripts and leave
   `run-stub-check.sh` alone** — rejected. `run-stub-check.sh` fails
   today with a raw shell "No such file or directory" (not even a FAIL
   line) when `${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh`
   doesn't exist outside spawn — this is the exact misleading-failure
   shape the issue calls out, and leaving it unfixed means a plain
   checkout still can't tell env-unreachable from a real regression for
   that script.

## What will be done
- Vendor `tests/lib/test_env_resolve.py`: a verbatim copy of the
  on-the-record `gates/test_env_resolve.py` reference implementation,
  with a header comment citing `docs/specs/test-env-resolution.md`
  (on-the-record, issue #551) as its source and stating it is not to be
  modified independently of that source.
- In each of the four `*/tests/run-gate-tests.sh`: before any fixture
  runs, invoke `python3 <repo_root>/tests/lib/test_env_resolve.py
  ../../core ../../../tokenmaxxxer-core/core` (sibling candidates
  matching this environment's layout, per the survey). On exit 75:
  print the SKIP message to stderr and exit 75 immediately — no
  fixtures run, no FAIL lines. On exit 0: export
  `CLAUDE_PLUGIN_ROOT_CORE` to the resolved path so the gate's own
  existing internal resolution (left untouched) finds it via step 1,
  then run the existing fixture loop unchanged, including the
  `missing-core` fixture which still deliberately overrides
  `CLAUDE_PLUGIN_ROOT_CORE` to a bogus path for that one case.
- In `sales/hooks/tests/run-stub-check.sh`: same pre-flight resolution
  call before invoking core's `stub-check.sh`; on exit 75, SKIP with
  message and exit 75 instead of letting the exec fail with a raw shell
  error; on exit 0, invoke `stub-check.sh` at the resolved path exactly
  as today (the `name-consistency-check.sh` invocation on the next line
  is untouched — it never depended on core).
- Each modified script gets a comment citing
  `docs/specs/test-env-resolution.md` (satisfies the issue's grep
  check).

## Out of scope
- Any change inside the gate hooks themselves
  (`*/hooks/*-gate.sh`) — their own core resolution and exit-2
  fail-closed behavior when core is broken/missing stays exactly as is.
- `sales/hooks/tests/name-consistency-check.sh` and
  `run-name-consistency-tests.sh` — no core dependency, convention's
  known exception applies verbatim, left untouched.
- The `missing-core` fixtures inside each `run-gate-tests.sh` — logic
  and expected outcome unchanged.
- Adding a network-fetch fallback for core — the convention explicitly
  excludes this from the canonical contract.
- Any change to the on-the-record repo itself.

## How you'll know it worked
- On a plain checkout with `CLAUDE_PLUGIN_ROOT_CORE` unset and no
  sibling core checkout reachable: running each of the five modified
  scripts produces zero FAIL lines and no raw shell errors — only the
  SKIP message on stderr, exit code 75.
- With `CLAUDE_PLUGIN_ROOT_CORE` pointed at a real core checkout: the
  exact same PASS/FAIL results as before this change, for every
  fixture in every script, including each `missing-core` fixture.
- `grep -rl test-env-resolution sales*/tests sales/hooks/tests` finds
  every modified script.
- If any script's failure once core is reachable turns out to be a real
  gate defect (not environment-related), it is recorded as a finding
  rather than masked by the new SKIP path.
