#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CHECK="$HERE/name-consistency-check.sh"
REPO_ROOT="$(cd "$HERE/../../.." && pwd -P)"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-40s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-40s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

# 1. Synthetic hand-rolled violation: a fixture repo whose README/manifest
# introduce a deliberately stale plugin name (a plausible-but-nonexistent
# 5th methodology plugin) must be caught.
td="$(mktemp -d)"
mkdir -p "$td/sales/.claude-plugin" "$td/sales-outreach-cadence/.claude-plugin"
printf '{"name":"sales"}\n' > "$td/sales/.claude-plugin/plugin.json"
printf '%s\n' 'Install `sales-outreach-cadence` for outreach cadence.' > "$td/README.md"
out="$("$CHECK" "$td" 2>&1)"; rc=$?
rm -rf "$td"
report deny "$([ $rc = 0 ] && echo allow || echo deny)" \
  "synthetic stale plugin-name in README caught"

# 2. This repo's own real README.md / hooks.json files must pass clean.
out="$("$CHECK" "$REPO_ROOT" 2>&1)"; rc=$?
report allow "$([ $rc = 0 ] && echo allow || echo deny)" \
  "real repo README/manifests pass clean"
echo "$out"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
