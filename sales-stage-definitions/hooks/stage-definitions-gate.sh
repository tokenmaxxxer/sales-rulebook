#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "stage-definitions-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${SALES_STAGE_DEFINITIONS_GATE_OFF:-}" || { trap - EXIT; gate_allow; }
# PreToolUse gate (Write|Edit|MultiEdit) — enforces the sales role's
# stage-definitions methodology (docs/issue-1/proposals/methodology-norms.md
# (b) Stage definitions) on docs/issue-<n>/reports/sales.md. On top of
# (never instead of) core canon's generic record-fields-gate.sh.
#
# Requires 5-7 detected stage sections (structure-scoped, via markdown
# heading delimiters), each with >=2 falsifiable past-tense exit criteria
# and a named next-stage handoff (label-adjacent-value-capture, not
# substring presence anywhere in the doc).
#
# Kill switch: export SALES_STAGE_DEFINITIONS_GATE_OFF=1 (unrecognized
# values stay ACTIVE; only recognized on-spellings 1/true/yes/on disable).

role="${CLAUDE_ROLE:-sales}"
deny() { gate_deny "$role" "$1"; }

[ "$role" = "sales" ] || { trap - EXIT; gate_allow; }
command -v python3 >/dev/null 2>&1 || deny "stage-definitions-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ]; then trap - EXIT; gate_allow; fi

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
    import importlib.util, json, os, posixpath, re, sys

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)

    def deny(m):
        sys.stderr.write("sales: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("SD_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict) or tool not in ("Write", "Edit", "MultiEdit", "Bash"):
        sys.exit(0)

    root = os.environ["SD_ROOT"]
    TARGET_RE = re.compile(r'^docs/issue-[0-9]+/reports/sales\.md$')

    if tool == "Bash":
        cmd = ti.get("command")
        if not isinstance(cmd, str) or not cmd:
            sys.exit(0)
        path = None
        for tok in gate_lib.gate_bash_write_targets(cmd):
            rel_tok = gate_lib.gate_normalize_path(root, tok)
            if rel_tok is not None and TARGET_RE.match(rel_tok):
                path = tok
                break
        if path is None:
            sys.exit(0)
    else:
        path = ti.get("file_path")
        if not isinstance(path, str) or not path:
            sys.exit(0)

    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None:
        sys.exit(0)
    if not TARGET_RE.match(rel):
        sys.exit(0)

    root_fs = posixpath.normpath(root.replace("\\", "/"))
    r = posixpath.join(root_fs, rel)

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed on stage definitions." % rel)

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so stage-definitions can be "
            "checked." % (rel, tool)
        )

    # ---- structure-scoped semantic check ----
    # A "stage section" is a markdown heading of the form
    # "## Stage N: <name>" (or "### Stage N: <name>"). Anything mentioning
    # stage-related words outside of such a heading's scope is prose, not
    # a stage definition, and does not count.
    HEADING_RE = re.compile(r'^#{2,4}\s*Stage\s+(\d+)\s*[:\-]\s*(.+?)\s*$', re.IGNORECASE | re.MULTILINE)
    headings = list(HEADING_RE.finditer(new_text))

    if not headings:
        deny(
            "stage-definitions deliverable has no detected stage sections (expected "
            "headings of the form '## Stage N: <name>'). Per "
            "docs/issue-1/proposals/methodology-norms.md (b) Stage definitions: 5-7 "
            "stages required."
        )

    stage_count = len(headings)
    if stage_count < 5 or stage_count > 7:
        deny(
            "stage-definitions deliverable has %d detected stage section(s); must be "
            "5-7. Per docs/issue-1/proposals/methodology-norms.md (b) Stage definitions."
            % stage_count
        )

    # Scope each stage section: text between this heading and the next
    # (or end of doc).
    sections = []
    for i, m in enumerate(headings):
        start = m.end()
        end = headings[i + 1].start() if i + 1 < len(headings) else len(new_text)
        sections.append((m.group(1), m.group(2).strip(), new_text[start:end]))

    REP_ACTIVITY_VERBS = ["had a call", "did a demo", "presented to", "called the",
                          "had good conversation", "had a conversation", "reached out to"]

    HANDOFF_PLACEHOLDERS = {"tbd", "unknown", "blocked", "n/a", "?"}
    HANDOFF_PLACEHOLDER_PREFIXES = ("tbd", "unknown", "blocked", "n/a")

    # label-adjacent-value-capture: `Label: value`, tolerating a
    # `Label:\nvalue` split across lines.
    def capture_label_value(text, label_alts):
        pat = re.compile(
            r'^\s*[-*]?\s*(?:%s)\s*[:\-]\s*(.*)$' % label_alts,
            re.IGNORECASE | re.MULTILINE,
        )
        m = pat.search(text)
        if not m:
            return None
        val = m.group(1).strip()
        if not val:
            # Label:\nvalue split across lines — take the next non-blank line.
            rest = text[m.end():]
            for line in rest.splitlines():
                line = line.strip()
                if line:
                    val = line
                    break
        return val if val else None

    problems = []

    for num, name, body in sections:
        low_name = name.lower()
        for verb in REP_ACTIVITY_VERBS:
            if verb in low_name:
                problems.append(
                    "Stage %s ('%s') uses rep-activity phrasing (%r) instead of a "
                    "completed buyer action in past tense" % (num, name, verb)
                )
                break

        # exit criteria: list items/lines within this section's scope,
        # under an "Exit criteria" label, excluding the handoff line.
        criteria_block_m = re.search(
            r'(?:exit\s*criteria)\s*[:\-]?\s*\n(.*?)(?=\n\s*(?:next[- ]stage|handoff)\s*[:\-]|\Z)',
            body, re.IGNORECASE | re.DOTALL,
        )
        criteria_lines = []
        if criteria_block_m:
            for line in criteria_block_m.group(1).splitlines():
                line = line.strip()
                if re.match(r'^[-*]\s*\S', line):
                    criteria_lines.append(re.sub(r'^[-*]\s*', '', line))

        if len(criteria_lines) < 2:
            problems.append(
                "Stage %s ('%s') has %d falsifiable exit criterion/criteria (found via "
                "structure-scoped list scan); must have >=2" % (num, name, len(criteria_lines))
            )
        else:
            for verb in REP_ACTIVITY_VERBS:
                if any(verb in c.lower() for c in criteria_lines):
                    problems.append(
                        "Stage %s ('%s') has an exit criterion using rep-activity "
                        "phrasing (%r) instead of a completed buyer action in past "
                        "tense" % (num, name, verb)
                    )
                    break

        handoff_val = capture_label_value(body, r'next[- ]stage(?:\s*handoff)?|handoff')
        if not handoff_val:
            problems.append(
                "Stage %s ('%s') is missing a named next-stage handoff" % (num, name)
            )
        else:
            hv_low = handoff_val.strip().lower().strip("*_ ")
            is_placeholder = hv_low in HANDOFF_PLACEHOLDERS or any(
                hv_low.startswith(p) for p in HANDOFF_PLACEHOLDER_PREFIXES
            )
            if is_placeholder:
                problems.append(
                    "Stage %s ('%s') next-stage handoff is a placeholder (%r), not a "
                    "named stage" % (num, name, handoff_val)
                )

    if problems:
        deny(
            "stage-definitions deliverable fails the structure-scoped shape check: %s. "
            "Per docs/issue-1/proposals/methodology-norms.md (b) Stage definitions: 5-7 "
            "stages, >=2 falsifiable past-tense exit criteria per stage, named "
            "next-stage handoff." % "; ".join(problems)
        )

    sys.exit(0)
except SystemExit:
    raise
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
