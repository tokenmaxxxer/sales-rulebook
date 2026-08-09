#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Pre-flight core resolution per docs/specs/test-env-resolution.md
# (on-the-record, issue #551): outside the spawn env, SKIP instead of
# letting the exec below fail with a raw shell "No such file or directory".
# The documented CORE_PLUGIN_ROOT override (docs/handbooks/stub-check.md)
# always wins first, unchanged from prior behavior — the resolver only
# runs to find a fallback when the caller hasn't set it.
if [ -n "${CORE_PLUGIN_ROOT:-}" ]; then
  resolved="$CORE_PLUGIN_ROOT"
else
  resolved="$(python3 "$HERE/../../../tests/lib/test_env_resolve.py" "$HERE/../../../../core" "$HERE/../../../../../tokenmaxxxer-core/core")"
  rc=$?
  [ "$rc" -eq 75 ] && exit 75
fi

"$resolved/hooks/tests/stub-check.sh" "$(dirname "$0")/.."

# sales-local: old role-names/ghost-file hard error (issue-16 (d)).
"$(dirname "$0")/name-consistency-check.sh" "$(cd "$(dirname "$0")/../../.." && pwd -P)"
