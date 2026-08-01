#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${SALES_PLAYBOOK_GATE_OFF:-}" || { trap - EXIT; gate_allow; }
# PreToolUse gate (Write|Edit|MultiEdit) — enforces the sales role's
# playbook methodology (docs/issue-1/proposals/methodology-norms.md (b)
# Sales playbook) on docs/issue-<n>/reports/sales.md. On top of (never
# instead of) core canon's generic record-fields-gate.sh.
#
# Requires all five sections present as actual markdown headings (process
# overview, qualification framework, ICP/persona, objection-handling,
# metrics), scoped to their own section body, and denies when
# messaging-script/positioning-copy content is detected inline within a
# scoped section rather than referenced (the marketing hand-off boundary).
#
# Kill switch: export SALES_PLAYBOOK_GATE_OFF=1

role="${CLAUDE_ROLE:-sales}"
deny() { gate_deny "$role" "$1"; }

[ "$role" = "sales" ] || gate_allow
command -v python3 >/dev/null 2>&1 || deny "playbook-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || gate_allow

_target="$(printf '%s' "$payload" | GATE_LIB_PY="$GATE_LIB_PY" python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    v=ti.get("file_path")
    if isinstance(v,str) and v: print(v)
' 2>/dev/null || true)"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
_under() {
  [ -z "$2" ] && return 0
  GATE_LIB_PY="$GATE_LIB_PY" python3 -c '
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(spec); spec.loader.exec_module(gate_lib)
r,t=sys.argv[1],sys.argv[2]
try: rr = os.path.realpath(r).replace("\\\\","/")
except Exception: sys.exit(1)
rel = gate_lib.gate_normalize_path(rr, t)
sys.exit(0 if rel is not None else 1)
' "$1" "$2"
}

root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR" && _under "$CLAUDE_PROJECT_DIR" "$_target"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  d="$_target"; [ -n "$d" ] || d="$(pwd -P)"; [ -d "$d" ] || d="$(dirname "$d")"
  root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; failing closed (playbook check cannot run)."

PB_PAYLOAD="$payload" PB_ROOT="$root" GATE_LIB_PY="$GATE_LIB_PY" \
python3 <<'PY'
import sys as _fc_sys
try:
    import importlib.util, json, os, re, sys

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)

    def deny(m):
        sys.stderr.write("sales: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("PB_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict) or tool not in ("Write", "Edit", "MultiEdit"):
        sys.exit(0)

    root = os.environ["PB_ROOT"]
    TARGET_RE = re.compile(r'^docs/issue-[0-9]+/reports/sales\.md$')

    path = ti.get("file_path")
    if not isinstance(path, str) or not path:
        sys.exit(0)

    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None:
        sys.exit(0)
    if not TARGET_RE.match(rel):
        sys.exit(0)

    r = os.path.join(root, rel)
    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on the playbook." % rel)

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok or new_text is None:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so playbook sections can be "
            "checked." % (rel, tool)
        )

    lines = new_text.splitlines()

    # Locate markdown heading lines: (level, title-lowercased-stripped, index)
    heading_re = re.compile(r'^(#{1,6})\s+(.*?)\s*$')
    headings = []
    for i, ln in enumerate(lines):
        m = heading_re.match(ln)
        if m:
            headings.append((len(m.group(1)), m.group(2).strip().lower(), i))

    if not headings:
        sys.exit(0)  # record never documents a playbook deliverable — out of scope

    mentions_playbook = any("playbook" in h[1] for h in headings) or "playbook" in lines[0].lower() if lines else False
    if not mentions_playbook:
        sys.exit(0)  # record never documents a playbook deliverable via a heading — out of scope

    SECTION_ALIASES = {
        "process-overview": ["process overview"],
        "qualification-framework": ["qualification framework"],
        "icp-persona": ["icp / persona summary", "icp/persona summary", "icp persona summary",
                        "buyer persona", "persona summary", "icp"],
        "objection-handling-competitive-notes": [
            "objection-handling and competitive notes", "objection handling and competitive notes",
            "objection-handling", "objection handling", "competitive notes",
        ],
        "metrics": ["metrics"],
    }

    def section_body(idx):
        """Return the lines of the section body starting after heading at idx,
        up to (not including) the next heading of equal or higher level."""
        lvl = headings[idx][0]
        start = headings[idx][2] + 1
        end = len(lines)
        for j in range(idx + 1, len(headings)):
            if headings[j][0] <= lvl:
                end = headings[j][2]
                break
        return lines[start:end]

    def heading_matches(title, aliases):
        for a in aliases:
            if title == a:
                return True
        return False

    missing = []
    section_indices = {}
    for key, aliases in SECTION_ALIASES.items():
        found_idx = None
        for hi, (lvl, title, i) in enumerate(headings):
            if heading_matches(title, aliases):
                found_idx = hi
                break
        if found_idx is None:
            missing.append(key)
        else:
            section_indices[key] = found_idx

    # Marketing hand-off boundary: scoped to the objection-handling and
    # metrics sections' bodies plus any prose after the last heading
    # (where a playbook doc conventionally places hand-off notes), not
    # scanned indiscriminately across the whole document.
    messaging_needles = (
        "messaging script", "positioning copy", "sample email:",
        "email template", "call script",
    )
    scoped_text_parts = []
    for key in ("objection-handling-competitive-notes", "metrics"):
        if key in section_indices:
            scoped_text_parts.append("\n".join(section_body(section_indices[key])))
    # trailing prose after the final heading (hand-off note area)
    if headings:
        _, _, last_i = headings[-1]
        trailing_start = last_i + 1
        scoped_text_parts.append("\n".join(lines[trailing_start:]))
    scoped_low = "\n".join(scoped_text_parts).lower()

    if any(nd in scoped_low for nd in messaging_needles):
        missing.append("inline-messaging-copy-detected (must reference marketing's asset, not duplicate it)")

    if missing:
        deny(
            "sales playbook deliverable is missing required element(s) or crosses the "
            "marketing hand-off boundary: %s. Per docs/issue-1/proposals/"
            "methodology-norms.md (b) Sales playbook: all five sections (process "
            "overview, qualification framework, ICP/persona, objection-handling, "
            "metrics) must be present as actual headings, and messaging scripts/"
            "positioning copy must be referenced from marketing's assets, never "
            "duplicated inline." % ", ".join(missing)
        )

    sys.exit(0)
except Exception as _fc_e:
    _fc_sys.stderr.write("playbook-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "sales: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
