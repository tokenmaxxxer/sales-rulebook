#!/usr/bin/env bash
# Sales-local hard-error check (issue-16 (d)): README.md and every
# hooks.json in this repo must reference only the plugin names this repo
# actually ships — no old role-name / ghost-file drift. Self-describing:
# the known-good set is read out of each *.claude-plugin/plugin.json*
# "name" field, never hardcoded, so the check tracks whatever plugins the
# repo ships instead of drifting from them.
#
# This is sales-local (not core canon) because self-naming consistency is
# specific to this repo's own plugin set, unlike stub-check.sh's
# drift-recurrence detection which is core canon referenced by
# run-stub-check.sh.
#
# Usage: name-consistency-check.sh [repo-root]
set -uo pipefail

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)}"
[ -d "$root" ] || { echo "name-consistency-check: no such directory: $root" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || { echo "name-consistency-check: requires python3, which is not on PATH" >&2; exit 2; }

python3 - "$root" <<'PY'
import glob, json, os, re, sys

root = sys.argv[1]

known = set()
for pj in sorted(glob.glob(os.path.join(root, "*", ".claude-plugin", "plugin.json"))):
    try:
        with open(pj, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError) as e:
        print("name-consistency-check: cannot read/parse %s: %r" % (pj, e), file=sys.stderr)
        sys.exit(2)
    name = data.get("name")
    if isinstance(name, str) and name:
        known.add(name)

if not known:
    print("name-consistency-check: no plugin.json files found under %s — nothing to check" % root, file=sys.stderr)
    sys.exit(2)

# The repo's own name is a title/marketplace-add token, not a plugin
# reference — README.md conventionally opens with it and cites it in the
# `claude plugin marketplace add tokenmaxxxer/sales-rulebook` install line.
# The on-disk directory name varies by checkout (e.g. worktree suffixes),
# so this is the repo's fixed GitHub name, not a filesystem lookup.
known.add("sales-rulebook")

targets = [os.path.join(root, "README.md")]
targets += sorted(glob.glob(os.path.join(root, "*", "hooks", "hooks.json")))
targets = [t for t in targets if os.path.isfile(t)]

TOKEN_RE = re.compile(r"\bsales(?:-[a-z]+)*\b")

rc = 0
for path in targets:
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    bad = sorted({m.group(0) for m in TOKEN_RE.finditer(text) if m.group(0) not in known})
    if bad:
        rc = 1
        rel = os.path.relpath(path, root)
        print("name-consistency-check: FAIL — %s: unknown plugin-name-shaped token(s): %s" % (rel, ", ".join(bad)), file=sys.stderr)

if rc == 0:
    print("name-consistency-check: ok — %d file(s) checked against known-good set {%s}" % (len(targets), ", ".join(sorted(known))))

sys.exit(rc)
PY
