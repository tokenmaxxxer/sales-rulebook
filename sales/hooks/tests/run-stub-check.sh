#!/usr/bin/env bash
set -euo pipefail

"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" "$(dirname "$0")/.."

# sales-local: old role-names/ghost-file hard error (issue-16 (d)).
"$(dirname "$0")/name-consistency-check.sh" "$(cd "$(dirname "$0")/../../.." && pwd -P)"
