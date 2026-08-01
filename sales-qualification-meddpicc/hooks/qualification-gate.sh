#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${SALES_QUALIFICATION_GATE_OFF:-}" || { trap - EXIT; gate_allow; }
# PreToolUse gate (Write|Edit|MultiEdit) — enforces the sales role's
# qualification-criteria methodology (docs/issue-1/proposals/
# methodology-norms.md (b) Qualification criteria) on
# docs/issue-<n>/reports/sales.md. On top of (never instead of) core canon's
# generic record-fields-gate.sh.
#
# Requires framework_used present with a MEDDPICC or BANT value (not a bare
# key). Under MEDDPICC, requires all 8 fields (Metrics, Economic Buyer,
# Decision Criteria, Decision Process, Paper Process, Identify Pain,
# Champion, Competition) present with a value or an explicit
# unknown/blocked/TBD marker — no field silently omitted (phase-2 approval
# addendum: "EB/Champion 외 MEDDPICC 전 필드 검사 추가"). When the record
# states an opportunity has advanced past initial qualification, requires
# non-TBD economic_buyer and champion specifically.
#
# Semantic checks are section-scoped (from the framework_used declaration
# to the next heading of equal-or-higher level or EOF) and label-adjacent
# value-capturing, not a whole-document substring scan (issue-13 phase 2).
#
# Kill switch: export SALES_QUALIFICATION_GATE_OFF=1
# (unrecognized values stay ACTIVE — see gate_kill_switch_active)

role="${CLAUDE_ROLE:-sales}"
deny() { gate_deny "$role" "$1"; }

[ "$role" = "sales" ] || exit 0
command -v python3 >/dev/null 2>&1 || deny "qualification-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

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
[ -z "$root" ] && deny "no project root could be determined; failing closed (qualification check cannot run)."

QG_PAYLOAD="$payload" QG_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys
try:
    import importlib.util, json, os, posixpath, re, sys

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    def deny(m):
        sys.stderr.write("sales: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("QG_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict) or tool not in ("Write", "Edit", "MultiEdit"):
        sys.exit(0)

    root = posixpath.normpath(os.environ["QG_ROOT"].replace("\\", "/"))
    TARGET_RE = re.compile(r'^docs/issue-[0-9]+/reports/sales\.md$')

    path = ti.get("file_path")
    if not isinstance(path, str) or not path:
        sys.exit(0)

    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None:
        sys.exit(0)
    if not TARGET_RE.match(rel):
        sys.exit(0)

    r = posixpath.join(root, rel) if rel else root

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on qualification criteria." % rel)

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so qualification fields can be "
            "checked." % (rel, tool)
        )

    text = new_text

    HEADING_RE = re.compile(r'^(#{1,6})\s')
    FRAMEWORK_RE = re.compile(r'^\s*[-*]?\s*framework_used\s*[:\-]\s*(.+)\s*$', re.IGNORECASE)

    def find_section(lines):
        """Return (start_idx, end_idx, framework_value) for the qualification
        section: from the framework_used-declaring line to the next heading
        of equal-or-higher level, or EOF. None if not found."""
        for i, line in enumerate(lines):
            m = FRAMEWORK_RE.match(line)
            if m:
                start_level = None
                # look backwards for the nearest heading to determine "equal
                # or higher level" boundary; if none precedes, any heading
                # ends the section.
                for j in range(i, -1, -1):
                    hm = HEADING_RE.match(lines[j])
                    if hm:
                        start_level = len(hm.group(1))
                        break
                end = len(lines)
                for k in range(i + 1, len(lines)):
                    hm = HEADING_RE.match(lines[k])
                    if hm:
                        level = len(hm.group(1))
                        if start_level is None or level <= start_level:
                            end = k
                            break
                return i, end, m.group(1).strip()
        return None

    lines = text.split("\n")
    section = find_section(lines)

    TBD_VALUES = {"tbd", "unknown", "blocked", "n/a", "?"}
    TBD_PREFIXES = ("tbd ", "unknown ", "blocked ")

    def is_tbd(value):
        v = value.strip().lower()
        if v in TBD_VALUES:
            return True
        return any(v.startswith(p) for p in TBD_PREFIXES)

    def find_field(section_lines, aliases):
        """Search section_lines for a label-adjacent value for any alias.
        Returns (found, value_or_None). found True with value None means
        the label appears with no adjacent value (still counts as
        omitted, per contract: bare mention doesn't count as present)."""
        alias_pat = "|".join(re.escape(a) for a in aliases)
        label_re = re.compile(r'^\s*[-*]?\s*(?:%s)\s*[:\-]\s*(.*)$' % alias_pat, re.IGNORECASE)
        for idx, line in enumerate(section_lines):
            m = label_re.match(line)
            if not m:
                continue
            value = m.group(1).strip()
            if value:
                return True, value
            # Label:\nvalue tolerance — look at next non-blank line.
            for j in range(idx + 1, len(section_lines)):
                nxt = section_lines[j].strip()
                if nxt:
                    if HEADING_RE.match(section_lines[j]):
                        return True, None
                    return True, nxt
                if j - idx > 3:
                    break
            return True, None
        return False, None

    low = text.lower()

    def has_any(*needles):
        return any(nd in low for nd in needles)

    if section is None:
        sys.exit(0)  # record never declares framework_used — out of scope, not a qualification deliverable

    missing = []

    start, end, framework_value = section
    section_lines = lines[start:end]
    if not re.search(r'meddpicc|bant', framework_value, re.IGNORECASE):
        missing.append("framework_used (MEDDPICC | BANT)")

    is_meddpicc = bool(re.search(r'meddpicc', framework_value, re.IGNORECASE))

    # Full 8-field MEDDPICC check (approval addendum: not just EB/Champion).
    MEDDPICC_FIELDS = [
        ("metrics", ["metrics"]),
        ("economic_buyer", ["economic buyer", "economic_buyer"]),
        ("decision_criteria", ["decision criteria", "decision_criteria"]),
        ("decision_process", ["decision process", "decision_process"]),
        ("paper_process", ["paper process", "paper_process"]),
        ("identify_pain", ["identify pain", "identify_pain"]),
        ("champion", ["champion"]),
        ("competition", ["competition"]),
    ]

    field_values = {}
    if is_meddpicc:
        for field_name, aliases in MEDDPICC_FIELDS:
            found, value = find_field(section_lines, aliases)
            field_values[field_name] = value
            if not found or value is None:
                missing.append("%s (MEDDPICC field is silently omitted; requires a value or explicit unknown/blocked marker)" % field_name)

    # Advancement-past-initial-qualification check: EB + Champion must be named, not TBD.
    advanced = has_any(
        "advanced past initial qualification", "past initial qualification",
        "advanced to", "advancement claimed",
    )
    if advanced:
        found_eb, eb_val = find_field(section_lines, ["economic buyer", "economic_buyer"])
        found_champ, champ_val = find_field(section_lines, ["champion"])
        eb_tbd = (not found_eb) or eb_val is None or is_tbd(eb_val)
        champ_tbd = (not found_champ) or champ_val is None or is_tbd(champ_val)
        if eb_tbd:
            missing.append("economic_buyer (must be a named individual/role, not TBD, before advancement)")
        if champ_tbd:
            missing.append("champion (must be a named individual/role, not TBD, before advancement)")

    if missing:
        deny(
            "qualification-criteria deliverable is missing required element(s): %s. Per "
            "docs/issue-1/proposals/methodology-norms.md (b) Qualification criteria: no "
            "MEDDPICC field may be silently omitted, and Economic Buyer/Champion must be "
            "named before advancement past initial qualification." % ", ".join(missing)
        )

    sys.exit(0)
except SystemExit:
    raise
except Exception as _fc_e:
    _fc_sys.stderr.write("qualification-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "sales: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
