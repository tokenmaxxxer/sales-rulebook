# Handbook — test-env resolution for gate-test scripts

This rulebook's core-dependent gate-test scripts —
`sales-proposal-norm/tests/run-gate-tests.sh`,
`sales-stage-definitions/tests/run-gate-tests.sh`,
`sales-qualification-meddpicc/tests/run-gate-tests.sh`,
`sales-playbook/tests/run-gate-tests.sh`, and
`sales/hooks/tests/run-stub-check.sh` — pre-flight core resolution before
running any fixture, per the canonical convention
(`docs/specs/test-env-resolution.md`, on-the-record issue #551,
adopted issue #25).

## Resolution order

1. `$CLAUDE_PLUGIN_ROOT_CORE` (if it contains `hooks/lib/gate-lib.sh`).
2. The script's own sibling-checkout candidates (e.g. `../../core`,
   `../../../tokenmaxxxer-core/core`, relative to the script).
3. Otherwise: SKIP — print
   `SKIP: core plugin unreachable — unverifiable outside spawn env` to
   stderr and exit `75` (`EX_TEMPFAIL`), never `0`/`1`/`2`.

The reference resolver is vendored verbatim at
`tests/lib/test_env_resolve.py` — do not edit it independently of
`docs/specs/test-env-resolution.md`; port upstream changes instead.

## How to run

    bash sales-proposal-norm/tests/run-gate-tests.sh
    bash sales-stage-definitions/tests/run-gate-tests.sh
    bash sales-qualification-meddpicc/tests/run-gate-tests.sh
    bash sales-playbook/tests/run-gate-tests.sh
    bash sales/hooks/tests/run-stub-check.sh

Exit `0` means the fixture loop ran and all fixtures passed. Exit `75`
means SKIP (core unreachable) — not a failure. Any other nonzero exit
means one or more fixtures failed with core reachable — a real defect.

`sales/hooks/tests/run-stub-check.sh` additionally honors the
documented `CORE_PLUGIN_ROOT` override (see
`docs/handbooks/stub-check.md`) ahead of this resolution order.

## Known exception

`sales/hooks/tests/name-consistency-check.sh` and
`sales/hooks/tests/run-name-consistency-tests.sh` never depend on core
and are not part of this convention.
