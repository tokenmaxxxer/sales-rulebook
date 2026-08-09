# Handbook — stub-check drift-recurrence check

`sales/hooks/tests/run-stub-check.sh` is a thin wrapper referencing core's
canon drift-recurrence check (`core/hooks/tests/stub-check.sh`, core issue
#69). This rulebook never vendors the check itself — the file contains only
the sanctioned invocation line:

    "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" "$(dirname "$0")/.."

## When to run it

Run before treating any change to `sales/hooks/directive.sh` or
`sales/hooks/hooks.json` as done.

## How to run it

    bash sales/hooks/tests/run-stub-check.sh

If `CORE_PLUGIN_ROOT` is set, it is used directly (unchanged from prior
behavior) — override with it if your install doesn't place core as a
literal sibling of `sales/`:

    CORE_PLUGIN_ROOT=/path/to/core bash sales/hooks/tests/run-stub-check.sh

If `CORE_PLUGIN_ROOT` is unset, the script pre-flights core resolution
per the canonical test-env resolution convention
(`docs/specs/test-env-resolution.md`, on-the-record issue #551, issue
#25): `$CLAUDE_PLUGIN_ROOT_CORE`, then sibling-checkout candidates, then
SKIP.

Exit code 0 means PASS. Exit code 75 means SKIP — core is unreachable
outside the spawn env; this is not a failure.
