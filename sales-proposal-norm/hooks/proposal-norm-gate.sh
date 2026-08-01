#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${SALES_PROPOSAL_NORM_GATE_OFF:-}" || { trap - EXIT; gate_allow; }
# PreToolUse gate (Write|Edit|MultiEdit) — enforces the sales role's phase-1
# proposal norm (docs/issue-1/proposals/methodology-norms.md (a)) on any
# write to docs/issue-<n>/proposals/*sales*.md. On top of (never instead of)
# core canon's generic record-fields-gate.sh.
#
# Requires six sections present, as markdown headings/labels, in order:
# status banner, scope, guiding principle, per-item breakdown, adoption
# rationale, plugin-reflection plan.
#
# Kill switch: export SALES_PROPOSAL_NORM_GATE_OFF=1 (recognized on-spellings
# only: 1/true/yes/on, case-insensitive; anything else, including an
# unrecognized typo, keeps the gate ACTIVE).

role="${CLAUDE_ROLE:-sales}"
deny() { gate_deny "$role" "$1"; }

[ "$role" = "sales" ] || gate_allow
command -v python3 >/dev/null 2>&1 || deny "proposal-norm-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || gate_allow

_target="$(printf '%s' "$payload" | python3 -c '
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
  python3 -c '
import os,posixpath,sys
r,t=sys.argv[1],sys.argv[2]
try: rr=posixpath.normpath(os.path.realpath(r).replace("\\","/"))
except Exception: sys.exit(1)
n=t.replace("\\","/"); a=n if posixpath.isabs(n) else posixpath.join(rr,n)
a=posixpath.normpath(a); real=posixpath.normpath(os.path.realpath(a).replace("\\","/"))
sys.exit(0 if (real==rr or real.startswith(rr+"/")) else 1)
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
[ -z "$root" ] && deny "no project root could be determined; failing closed (proposal-norm check cannot run)."

PN_PAYLOAD="$payload" PN_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys
try:
    import importlib.util, json, os, posixpath, re, sys

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    def deny(m):
        sys.stderr.write("sales: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("PN_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict) or tool not in ("Write", "Edit", "MultiEdit"):
        sys.exit(0)

    root = posixpath.normpath(os.environ["PN_ROOT"].replace("\\", "/"))
    TARGET_RE = re.compile(r'^docs/issue-[0-9]+/proposals/.*sales.*\.md$', re.I)

    path = ti.get("file_path")
    if not isinstance(path, str) or not path:
        sys.exit(0)

    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None or not TARGET_RE.match(rel):
        sys.exit(0)

    r = posixpath.join(root, rel)

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on the proposal norm." % rel)

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so the proposal-norm sections can be "
            "checked." % (rel, tool)
        )

    # --- section-scoped, structure-based semantic check ---
    #
    # Required sections, in order, each identified by a markdown heading
    # line (any level, `^#{1,6}\s+...`) or, for the status banner only (it
    # is a label:value line at the top of the document rather than a
    # heading), a label-adjacent-value line. A section name mentioned only
    # in unrelated prose (not as an actual heading) does not count.
    SECTIONS = [
        ("status-banner", None),  # handled specially below (label:value)
        ("scope", [r"scope"]),
        ("guiding-principle", [r"guiding\s+principle"]),
        ("per-item-breakdown", [
            r"per[\s-]item\s+breakdown",
            r"mandatory\s+plugin\s+list",
            r"per[\s-]plugin\s+breakdown",
        ]),
        ("adoption-rationale", [r"adoption\s+rationale"]),
        ("plugin-reflection-plan", [r"plugin[\s-]reflection\s+plan"]),
    ]

    lines = new_text.splitlines()
    HEADING_RE = re.compile(r'^\s{0,3}#{1,6}\s+(.*?)\s*$')

    # status banner: a "Status:" label with a non-empty value, tolerating
    # the value on the very next non-blank line.
    STATUS_LABEL_RE = re.compile(r'^\s*[-*]?\s*status\s*[:\-]\s*(.*)$', re.I)

    def find_status_banner():
        for i, ln in enumerate(lines):
            m = STATUS_LABEL_RE.match(ln)
            if not m:
                continue
            val = m.group(1).strip()
            if val:
                return i
            # value on next non-blank line, unless that line is itself a
            # heading (a heading can never serve as a label's value)
            for j in range(i + 1, min(i + 4, len(lines))):
                nxt = lines[j].strip()
                if nxt:
                    return i if not HEADING_RE.match(lines[j]) else None
            return None
        return None

    # collect heading positions (line index -> normalized heading text)
    headings = []
    for i, ln in enumerate(lines):
        m = HEADING_RE.match(ln)
        if m:
            headings.append((i, m.group(1).strip().lower()))

    def find_heading(patterns):
        for i, text in headings:
            for pat in patterns:
                if re.search(pat, text, re.I):
                    return i
        return None

    positions = {}
    missing = []

    status_pos = find_status_banner()
    if status_pos is None:
        missing.append("status-banner")
    else:
        positions["status-banner"] = status_pos

    for name, patterns in SECTIONS[1:]:
        pos = find_heading(patterns)
        if pos is None:
            missing.append(name)
        else:
            positions[name] = pos

    if missing:
        deny(
            "phase-1 sales proposal is missing required section(s): %s. Per "
            "docs/issue-1/proposals/methodology-norms.md (a), a sales phase-1 proposal "
            "needs all six sections, in order: status banner, scope, guiding principle, "
            "per-item breakdown, adoption rationale, plugin-reflection plan." % ", ".join(missing)
        )

    # order check: positions must be non-decreasing in the required order
    order = [name for name, _ in SECTIONS]
    ordered_positions = [positions[name] for name in order]
    if ordered_positions != sorted(ordered_positions):
        deny(
            "phase-1 sales proposal's sections are present but out of order. Required "
            "order: status banner, scope, guiding principle, per-item breakdown, "
            "adoption rationale, plugin-reflection plan."
        )

    sys.exit(0)
except Exception as _fc_e:
    _fc_sys.stderr.write("proposal-norm-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "sales: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
