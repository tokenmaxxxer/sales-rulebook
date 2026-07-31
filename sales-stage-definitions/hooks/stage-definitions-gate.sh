#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — enforces the sales role's
# stage-definitions methodology (docs/issue-1/proposals/methodology-norms.md
# (b) Stage definitions) on docs/issue-<n>/reports/sales.md. On top of
# (never instead of) core canon's generic record-fields-gate.sh.
#
# Requires stage_count as an integer in [5,7], exit_criteria_present stated
# per stage, and denies when a stage name matches a rep-activity verb
# (documented heuristic, not a full parse — matches this repo family's
# accepted keyword/regex precision level).
#
# Kill switch: export SALES_STAGE_DEFINITIONS_GATE_OFF=1
set -uo pipefail

role="${CLAUDE_ROLE:-sales}"
deny() { echo "${role}: refused — $1" >&2; exit 2; }

case "${SALES_STAGE_DEFINITIONS_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

[ "$role" = "sales" ] || exit 0
command -v python3 >/dev/null 2>&1 || deny "stage-definitions-gate.sh requires python3, which is not on PATH; denying rather than guessing."

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
[ -z "$root" ] && deny "no project root could be determined; failing closed (stage-definitions check cannot run)."

SD_PAYLOAD="$payload" SD_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("sales: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("SD_PAYLOAD", "")
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

    root = posixpath.normpath(os.environ["SD_ROOT"].replace("\\", "/"))
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
            deny("%s exists but cannot be read; failing closed on stage definitions." % rel)

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
            "Edit/MultiEdit whose old_string matches, so stage-definitions can be "
            "checked." % (rel, tool)
        )

    low = new_text.lower()

    def has_any(*needles):
        return any(nd in low for nd in needles)

    mentions_stage = has_any("stage definition", "stage_count", "stage count")
    if not mentions_stage:
        sys.exit(0)  # record never documents a stage-definitions deliverable — out of scope

    missing = []

    m = re.search(r'stage_count\s*[:=]\s*(\d+)', low)
    if not m:
        missing.append("stage_count (integer)")
    else:
        n = int(m.group(1))
        if n < 5 or n > 7:
            missing.append("stage_count in range 5-7 (found %d)" % n)

    if "exit_criteria_present" not in low:
        missing.append("exit_criteria_present (per stage)")

    REP_ACTIVITY_VERBS = ["had a call", "did a demo", "presented to", "called the",
                          "had good conversation", "had a conversation", "reached out to"]
    for verb in REP_ACTIVITY_VERBS:
        if verb in low:
            missing.append("stage name/criterion uses rep-activity phrasing (%r) instead of a completed buyer action in past tense" % verb)
            break

    if missing:
        deny(
            "stage-definitions deliverable is missing required element(s) or fails the "
            "shape check: %s. Per docs/issue-1/proposals/methodology-norms.md (b) Stage "
            "definitions: 5-7 stages, exit criteria stated per stage, past-tense "
            "completed-buyer-action naming (never rep activity/judgment)." % ", ".join(missing)
        )

    sys.exit(0)
except Exception as _fc_e:
    _fc_sys.stderr.write("stage-definitions-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "sales: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
