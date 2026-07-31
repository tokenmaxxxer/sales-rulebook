#!/usr/bin/env bash
set -euo pipefail

"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" "$(dirname "$0")/.."
