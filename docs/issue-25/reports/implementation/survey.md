# Current-state survey — issue #25

## Convention source
`on-the-record docs/specs/test-env-resolution.md` (issue #551), read in
full. Resolution order: `$CLAUDE_PLUGIN_ROOT_CORE` (if it contains a
non-empty `hooks/lib/gate-lib.sh`) -> first caller-supplied sibling
candidate with the same file -> SKIP (stderr message, exit 75
`EX_TEMPFAIL`, never colliding with a gate's own 0/1/2). Reference
resolver: `gates/test_env_resolve.py` in that repo, unit-tested by
`gates/test_test_env_resolve.py`. Known exception: a test suite that
never resolves core at all is out of scope for the convention.

## Test scripts in this repo (write set candidates)

| script | core dependency | current failure mode outside spawn |
|---|---|---|
| `sales-proposal-norm/tests/run-gate-tests.sh` | yes — invokes `hooks/proposal-norm-gate.sh`, which sources `${CLAUDE_PLUGIN_ROOT_CORE:-../../core}/hooks/lib/gate-lib.sh` | every non-missing-core case gets `exit-2` from the gate's own fail-closed source failure -> reported as FAIL, indistinguishable from a real regression |
| `sales-stage-definitions/tests/run-gate-tests.sh` | yes — same pattern, `hooks/stage-definitions-gate.sh` | same: blanket FAIL, not SKIP |
| `sales-qualification-meddpicc/tests/run-gate-tests.sh` | yes — same pattern, `hooks/qualification-gate.sh` | same |
| `sales-playbook/tests/run-gate-tests.sh` | yes — same pattern, `hooks/playbook-gate.sh` | same |
| `sales/hooks/tests/run-stub-check.sh` | yes — directly execs `${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh` | outside spawn, that path does not exist -> shell "No such file or directory" -> non-zero exit, no SKIP message at all |
| `sales/hooks/tests/name-consistency-check.sh` | **no** — pure Python glob/JSON check over this repo's own `*/.claude-plugin/plugin.json`, README.md, `*/hooks/hooks.json`; never touches core | none — already runs standalone; convention's known-exception clause applies verbatim |
| `sales/hooks/tests/run-name-consistency-tests.sh` | **no** — only drives the script above | same exception |

Each of the four `run-gate-tests.sh` scripts also carries a dedicated
`missing-core` fixture (`CLAUDE_PLUGIN_ROOT_CORE` pointed at a
deliberately bogus path) that asserts the *gate's own* production
fail-closed behavior (exit 2 / deny) — this is orthogonal to the new
pre-flight resolution check: it exercises resolution order step 1 (env
var wins even when it points nowhere), not the "core unreachable
anywhere" case the new check targets. Must keep passing unchanged.

## Gate scripts themselves (out of scope)
All four gate hooks (`hooks/*-gate.sh`) already implement their own
narrow fallback: `${CLAUDE_PLUGIN_ROOT_CORE:-<repo>/../../core}`, then
fail closed (exit 2) if `gate-lib.sh` still can't be sourced. That
fail-closed behavior is correct production behavior for a security gate
and is explicitly out of scope per the issue ("do not weaken any
assertion that runs when core IS reachable") — the fix belongs in the
*test* scripts wrapping them, not in gate production logic.

## Sibling-candidate paths available in this environment
`echo $CLAUDE_PLUGIN_ROOT_CORE` in the spawn env resolves to
`.../tokenmaxxxer/runs/rulebooks/tokenmaxxxer-core/core`. Outside spawn,
this checkout's siblings that could plausibly hold a core checkout:
`../../core` (relative to each plugin's `hooks/` dir — already what the
gate scripts themselves try) and `../tokenmaxxxer-core/core` /
`../../tokenmaxxxer-core/core` (matches the convention doc's own
example candidates and this environment's actual layout,
`~/tokenmaxxxer-core`). No live core checkout is reachable from a plain
clone of this repo alone, confirming the SKIP path is the one that
actually fires here today.

## Sibling rulebook precedent
`architecture-rulebook` (issue #22) already proposed adopting this same
convention with the same shape: vendor the on-the-record reference
resolver verbatim under `tests/lib/test_env_resolve.py`, call it as a
CLI from each test script's shell, branch on exit 75 vs 0. Consistent
with this convention being meant to stop each consumer hand-rolling its
own bash reimplementation.
