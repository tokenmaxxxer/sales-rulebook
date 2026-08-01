#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
GATE="$HOOKS/proposal-norm-gate.sh"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-30s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-30s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

# run <want> <name> <path> <content> [extra_env] [existing_path] [existing_content]
run() {
  local want="$1" name="$2" path="$3" content="$4" extra_env="${5:-}" existing_path="${6:-}" existing_content="${7:-}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$path")"
  if [ -n "$existing_path" ]; then
    mkdir -p "$td/$(dirname "$existing_path")"
    printf '%s' "$existing_content" > "$td/$existing_path"
  fi
  actual_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]},"cwd":sys.argv[3]}))' "$path" "$content" "$td")"
  out="$(env $extra_env CLAUDE_PROJECT_DIR="$td" CLAUDE_ROLE=sales TG_PAYLOAD="$actual_payload" \
    bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
  rc=$?
  rm -rf "$td"
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report "$1" "$got" "$name"
}

# run_raw: like run but sends a caller-provided raw payload string, and can
# invoke Edit/MultiEdit tool inputs (JSON built by caller, not simple Write).
run_raw() {
  local want="$1" name="$2" repo_setup="$3" raw_payload="$4" extra_env="${5:-}"
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  eval "$repo_setup"
  out="$(env $extra_env CLAUDE_PROJECT_DIR="$td" CLAUDE_ROLE=sales TG_PAYLOAD="$raw_payload" \
    bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
  rc=$?
  rm -rf "$td"
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report "$1" "$got" "$name"
}

COMPLETE='Status: phase-1-only.
## Scope
Scoped against the current-state survey.
## Guiding principle
One sentence.
## Per-item breakdown
Item one: does X.
## Adoption rationale
Sourced from Y.
## Plugin-reflection plan
Will touch Z.'

MISSING_RATIONALE='Status: phase-1-only.
## Scope
Scoped against the current-state survey.
## Guiding principle
One sentence.
## Per-item breakdown
Item one.
## Plugin-reflection plan
Will touch Z.'

run allow all-six-sections     "docs/issue-10/proposals/sales-thing.md" "$COMPLETE"
run deny  missing-rationale    "docs/issue-10/proposals/sales-thing.md" "$MISSING_RATIONALE"
run allow foreign-path         "docs/issue-10/proposals/pricing-thing.md" "nothing at all"
run allow kill-switch-set      "docs/issue-10/proposals/sales-thing.md" "$MISSING_RATIONALE" "SALES_PROPOSAL_NORM_GATE_OFF=1"

# 5. Kill-switch unrecognized-value case: typo must keep the gate ACTIVE.
run deny  kill-switch-typo-stays-active "docs/issue-10/proposals/sales-thing.md" "$MISSING_RATIONALE" "SALES_PROPOSAL_NORM_GATE_OFF=typo"

# 1. Edit case: old content is missing the rationale; the edit adds it.
run_raw allow edit-reconstructs-passing-doc '
  mkdir -p "$td/docs/issue-10/proposals"
  printf "%s" "$MISSING_RATIONALE" > "$td/docs/issue-10/proposals/sales-thing.md"
' "$(MISSING_RATIONALE="$MISSING_RATIONALE" python3 -c '
import json
payload = {
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "docs/issue-10/proposals/sales-thing.md",
    "old_string": "## Per-item breakdown\nItem one.\n## Plugin-reflection plan",
    "new_string": "## Per-item breakdown\nItem one.\n## Adoption rationale\nSourced from Y.\n## Plugin-reflection plan",
  },
}
print(json.dumps(payload))
')"

# 2. MultiEdit case: first edit inserts the rationale heading; second edit
# depends on the first (fills in the rationale body under the heading the
# first edit created).
run_raw allow multiedit-order-dependent '
  mkdir -p "$td/docs/issue-10/proposals"
  printf "%s" "$MISSING_RATIONALE" > "$td/docs/issue-10/proposals/sales-thing.md"
' "$(MISSING_RATIONALE="$MISSING_RATIONALE" python3 -c '
import json, os
payload = {
  "tool_name": "MultiEdit",
  "tool_input": {
    "file_path": "docs/issue-10/proposals/sales-thing.md",
    "edits": [
      {
        "old_string": "## Plugin-reflection plan",
        "new_string": "## Adoption rationale\nPLACEHOLDER\n## Plugin-reflection plan",
      },
      {
        "old_string": "## Adoption rationale\nPLACEHOLDER",
        "new_string": "## Adoption rationale\nSourced from Y.",
      },
    ],
  },
}
print(json.dumps(payload))
')"

# 3. replace_all:true case: old_string occurs twice; every occurrence must
# be replaced (here: two stray "TBDMARK" tokens both need clearing so the
# doc reads as complete).
REPEATED='Status: phase-1-only.
## Scope
Scoped against the current-state survey. TBDMARK
## Guiding principle
One sentence. TBDMARK
## Per-item breakdown
Item one.
## Adoption rationale
Sourced from Y.
## Plugin-reflection plan
Will touch Z.'
run_raw allow replace-all-true '
  mkdir -p "$td/docs/issue-10/proposals"
  printf "%s" "$REPEATED" > "$td/docs/issue-10/proposals/sales-thing.md"
' "$(REPEATED="$REPEATED" python3 -c '
import json, os
payload = {
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "docs/issue-10/proposals/sales-thing.md",
    "old_string": " TBDMARK",
    "new_string": "",
    "replace_all": True,
  },
}
print(json.dumps(payload))
')"

# 4. Malformed-JSON case.
run_raw deny malformed-json-denies '' 'not valid json at all'
run_raw deny bare-array-denies '' '[1,2,3]'

# 6. Absolute-path case: same result via absolute path resolved against
# CLAUDE_PROJECT_DIR as via the equivalent relative path.
td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-10/proposals"
abs_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]},"cwd":sys.argv[3]}))' "$td/docs/issue-10/proposals/sales-thing.md" "$COMPLETE" "$td")"
out="$(env CLAUDE_PROJECT_DIR="$td" CLAUDE_ROLE=sales TG_PAYLOAD="$abs_payload" bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
rc=$?; rm -rf "$td"
case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
report allow "$got" absolute-path-actual-check

# 7. Single-quote-in-payload case: a field value containing a literal '.
QUOTE_DOC="Status: phase-1-only.
## Scope
Scoped against the current-state survey.
## Guiding principle
One sentence.
## Per-item breakdown
Champion: Bob's team lead.
## Adoption rationale
Sourced from Y.
## Plugin-reflection plan
Will touch Z."
run allow single-quote-in-payload "docs/issue-10/proposals/sales-thing.md" "$QUOTE_DOC"

# 8. Section-scoping false-pass case: "Adoption rationale" mentioned only
# in unrelated prose (not as a heading) must still deny as missing.
PROSE_MENTION='Status: phase-1-only.
## Scope
Scoped against the current-state survey. We will draft an adoption rationale later in a follow-up doc, but not here.
## Guiding principle
One sentence.
## Per-item breakdown
Item one.
## Plugin-reflection plan
Will touch Z.'
run deny prose-mention-not-heading "docs/issue-10/proposals/sales-thing.md" "$PROSE_MENTION"

# 9. Adjacency-tolerant status-banner case: label and value split across
# lines must still be recognized as present... but when a required
# *section heading* is present only as a split label with no value, it
# must still deny. Here: Status label present but with an empty value (no
# value on the same or next line) must deny as missing.
EMPTY_STATUS='Status:

## Scope
Scoped against the current-state survey.
## Guiding principle
One sentence.
## Per-item breakdown
Item one.
## Adoption rationale
Sourced from Y.
## Plugin-reflection plan
Will touch Z.'
run deny empty-status-value-denies "docs/issue-10/proposals/sales-thing.md" "$EMPTY_STATUS"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
