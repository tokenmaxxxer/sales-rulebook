#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
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
# Kill switch: export SALES_QUALIFICATION_GATE_OFF=1
set -uo pipefail

role="${CLAUDE_ROLE:-sales}"
deny() { echo "${role}: refused — $1" >&2; exit 2; }

case "${SALES_QUALIFICATION_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

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
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("sales: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("QG_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        sys.exit(0)
    if not isinstance(ev, dict):
        sys.exit(0)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict) or tool not in ("Write", "Edit", "MultiEdit"):
        sys.exit(0)

    root = posixpath.normpath(os.environ["QG_ROOT"].replace("\\", "/"))
    TARGET_RE = re.compile(r'^docs/issue-[0-9]+/reports/sales\.md$')

    def resolve(p):
        n = p.replace("\\", "/")
        a = n if posixpath.isabs(n) else posixpath.join(root, n)
        a = posixpath.normpath(a)
        try:
            return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
        except OSError:
            return a

    path = ti.get("file_path")
    if not isinstance(path, str) or not path:
        sys.exit(0)

    r = resolve(path)
    if not r.startswith(root + "/"):
        sys.exit(0)
    rel = r[len(root):].lstrip("/")
    if not TARGET_RE.match(rel):
        sys.exit(0)

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on qualification criteria." % rel)

    new_text = None
    if tool == "Write":
        c = ti.get("content")
        if isinstance(c, str):
            new_text = c
    elif tool == "Edit":
        o, n = ti.get("old_string"), ti.get("new_string")
        if isinstance(o, str) and isinstance(n, str) and current is not None and o in current:
            new_text = current.replace(o, n, 1)
    elif tool == "MultiEdit":
        edits = ti.get("edits")
        text = current
        if isinstance(edits, list) and text is not None:
            ok = True
            for e in edits:
                if not isinstance(e, dict):
                    ok = False; break
                o, n = e.get("old_string"), e.get("new_string")
                if not isinstance(o, str) or not isinstance(n, str) or o not in text:
                    ok = False; break
                text = text.replace(o, n, 1)
            if ok:
                new_text = text

    if new_text is None:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so qualification fields can be "
            "checked." % (rel, tool)
        )

    low = new_text.lower()

    def has_any(*needles):
        return any(nd in low for nd in needles)

    mentions_qual = has_any("qualification criteria", "meddpicc", "bant", "framework_used")
    if not mentions_qual:
        sys.exit(0)  # record never documents a qualification-criteria deliverable — out of scope

    missing = []
    if "framework_used" not in low:
        missing.append("framework_used (MEDDPICC | BANT)")
    elif not has_any("meddpicc", "bant"):
        missing.append("framework_used (MEDDPICC | BANT)")

    is_meddpicc = "meddpicc" in low

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
    if is_meddpicc:
        for field_name, needles in MEDDPICC_FIELDS:
            if not has_any(*needles):
                missing.append("%s (MEDDPICC field is silently omitted; requires a value or explicit unknown/blocked marker)" % field_name)

    # Advancement-past-initial-qualification check: EB + Champion must be named, not TBD.
    advanced = has_any(
        "advanced past initial qualification", "past initial qualification",
        "advanced to", "advancement claimed",
    )
    if advanced:
        eb_tbd = has_any("economic buyer: tbd", "economic_buyer: tbd", "economic buyer: unknown", "economic_buyer: unknown") or not has_any("economic buyer", "economic_buyer")
        champ_tbd = has_any("champion: tbd", "champion: unknown") or "champion" not in low
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
