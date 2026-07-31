#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — sales-owned addendum to core's
# generic record-fields-gate.sh (§20 sections: what-was-done, why,
# upstream-basis, loop_state, open-findings).
#
# Core's engine (tokenmaxxxer-core/core/hooks/record-fields-gate.sh) has no
# per-role custom-field config surface today — only RECORD_FIELDS_TERMINAL_STATES
# for loop-state semantics. The three fields below are this role's own
# methodology decision (docs/issue-1/proposals/methodology-norms.md (d)),
# not a role-agnostic mechanic, so they live here rather than in core.
#
# On a write to this role's own record (docs/issue-<n>/reports/sales.md),
# whenever the resulting content documents one of the three `produces`
# deliverable kinds, require:
#   - framework_used: MEDDPICC | BANT   (qualification criteria)
#   - stage_count: <int>                (stage definitions)
#   - exit_criteria_present: true|false, per stage (stage definitions)
# A record that never mentions a qualification-criteria or stage-definition
# deliverable is out of scope for this check (nothing to validate yet).
#
# Kill switch: export SALES_RECORD_FIELDS_GATE_OFF=1
set -uo pipefail

role="${CLAUDE_ROLE:-}"
deny() { echo "${role:-sales-record-fields-gate}: refused — $1" >&2; exit 2; }

case "${SALES_RECORD_FIELDS_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

[ "$role" = "sales" ] || exit 0
command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

RF_PAYLOAD="$payload" ROLE="$role" python3 <<'PY'
import json, os, re, sys

def deny(m):
    sys.stderr.write("sales: refused — %s\n" % m)
    sys.exit(2)

raw = os.environ.get("RF_PAYLOAD", "")
try:
    ev = json.loads(raw) if raw else {}
except ValueError:
    sys.exit(0)  # not this gate's job to judge unparseable payloads; core's gate fails closed on that
if not isinstance(ev, dict):
    sys.exit(0)

tool = ev.get("tool_name")
ti = ev.get("tool_input")
if not isinstance(ti, dict) or tool not in ("Write", "Edit", "MultiEdit"):
    sys.exit(0)

path = ti.get("file_path")
if not isinstance(path, str) or not re.search(r'docs/issue-[0-9]+/reports/sales\.md$', path.replace("\\", "/")):
    sys.exit(0)

# Reconstruct resulting content the same way core's gate does: full text for
# Write, best-effort substitution for Edit/MultiEdit against the file on disk.
new_text = None
if tool == "Write":
    c = ti.get("content")
    if isinstance(c, str):
        new_text = c
else:
    try:
        with open(path, encoding="utf-8-sig") as fh:
            current = fh.read(1 << 20)
    except OSError:
        current = None
    if current is not None:
        if tool == "Edit":
            o, n = ti.get("old_string"), ti.get("new_string")
            if isinstance(o, str) and isinstance(n, str) and o in current:
                new_text = current.replace(o, n, 1)
        else:
            edits = ti.get("edits")
            text = current
            if isinstance(edits, list):
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
    sys.exit(0)  # can't determine resulting content; core's own gate already fails closed on that case

low = new_text.lower()
mentions_qual = "qualification criteria" in low or "meddpicc" in low or "bant" in low
mentions_stage = "stage definition" in low or "stage_count" in low

missing = []
if mentions_qual and "framework_used" not in low:
    missing.append("framework_used (MEDDPICC | BANT)")
if mentions_stage:
    if "stage_count" not in low:
        missing.append("stage_count")
    if "exit_criteria_present" not in low:
        missing.append("exit_criteria_present")

if missing:
    deny(
        "record documents a qualification-criteria or stage-definition deliverable "
        "but is missing required field(s): %s. Per docs/issue-1/proposals/"
        "methodology-norms.md (d)." % ", ".join(missing)
    )

sys.exit(0)
PY
exit $?
