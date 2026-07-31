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

By default this resolves core as a literal sibling of `sales/`
(`$CLAUDE_PLUGIN_ROOT/../core`). If your install doesn't place core there,
override with `CORE_PLUGIN_ROOT`:

    CORE_PLUGIN_ROOT=/path/to/core bash sales/hooks/tests/run-stub-check.sh

Exit code 0 means PASS.
