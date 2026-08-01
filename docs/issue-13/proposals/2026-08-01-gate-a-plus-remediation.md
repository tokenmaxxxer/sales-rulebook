# Proposal: sales rulebook gate remediation to grade A+ (issue-13)

Subject: issue-13. Phase 1 (proposal-only) — no code changes ship in this
PR. Phase 2 begins only after `APPROVE issue-13/sales`.

## Precondition status (must re-check before phase 2 starts)

Per the survey, core issue #72's shared library is proposed but not
delivered on `tokenmaxxxer-core`'s `main` as of this writing. **Phase 2
must not begin coding against `core/hooks/lib/gate-lib.sh` until that
file exists on core's `main`.** If core#72 phase 2 has not landed by the
time this PR is approved, phase 2 work here blocks and should say so on
the PR rather than vendoring a copy of the library (vendoring would
recreate exactly the "자체 재구현" the issue's precondition forbids, and
would additionally create a stub-check-flaggable duplicate per
`docs/handbooks/canon-scripts.md`'s manifest convention).

## 1. Reference-adopt gate-lib.sh/gate-lib.py — no reimplementation

Every one of the four sales gate scripts (`sales-qualification-meddpicc`,
`sales-proposal-norm`, `sales-stage-definitions`, `sales-playbook`)
switches its mechanical scaffolding to source the shared library, mirroring
the existing `sales/hooks/directive.sh` convention of resolving
`CLAUDE_PLUGIN_ROOT_CORE` with a `../../core` fallback:

```bash
#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active "${SALES_QUALIFICATION_GATE_OFF:-}" || { trap - EXIT; gate_allow; }
```

This replaces, per gate script:
- the hand-rolled `trap __fc EXIT` / `__fc()` pair → `gate_trap_fail_closed`
- the hand-rolled kill-switch `case` (fail-open-on-unrecognized-value bug)
  → `gate_kill_switch_active` (fail-closed-on-unrecognized-value, fixed)
- the hand-rolled `echo "...refused — ..." >&2; exit 2` → `gate_deny`
- the Python payload's hand-rolled `resolve()` / path-normalize → import
  `gate_lib.gate_normalize_path` via the `GATE_LIB_PY` env var the shell
  lib exports
- the Python payload's hand-rolled JSON-parse-or-exit-0 →
  `gate_lib.gate_parse_json_or_deny` (tightens malformed-JSON handling to
  *deny*, matching the issue's "malformed-JSON deny" requirement — the
  current sales gates exit 0/pass-through on bad JSON rather than deny)
- the Edit/MultiEdit reconstruction block →
  `gate_lib.gate_reconstruct_write(tool, tool_input, current_content)`,
  which is `replace_all`-aware for both Edit and per-edit MultiEdit, and
  additionally gains NotebookEdit support the sales gates don't have today
  (not required by the issue, but free once the shared function is used —
  not built specially, just inherited)

Each gate script keeps only what is genuinely its own: the target-path
regex (`docs/issue-<n>/reports/sales\.md`), the framework-detection
dispatch (MEDDPICC vs BANT), and the semantic field checks below. No gate
script re-implements trap/kill-switch/JSON-parse/path-normalize/
reconstruct logic after this change — a `stub-check`-style grep for those
patterns having zero matches outside `core/hooks/lib/` is part of the
mandatory test additions (§3).

## 2. Semantic checks: substring → section + adjacency + structure

The whole-document `has_any()` substring scan is replaced with a
section-scoped, field-adjacent check. Design (applies identically to all
four gates' respective field sets — MEDDPICC's 8 fields, BANT's 4, and
each other plugin's own required-field list):

1. **Locate the qualification section**, not the whole document. Find the
   MEDDPICC/BANT-declaring line (`framework_used: MEDDPICC`) and scope the
   check to text from that line to the next markdown heading of equal or
   higher level (`^#{1,N} `) or end-of-document — never a match anywhere
   else in the file. This alone kills the "competition mentioned in an
   unrelated paragraph" false-pass: an incidental "competition" 5 headings
   away, outside the scoped section, no longer counts.
2. **Field presence = label-adjacent-to-value, not word-appears**. Within
   the scoped section, require a line (or the label immediately followed
   by its value on the same or very next non-blank line, to tolerate
   `Label:\nvalue` markdown-table/list rendering) matching
   `^\s*[-*]?\s*(field label or its known synonyms)\s*[:\-]\s*(.+)$` with a
   non-empty, non-whitespace value group. A bare field name with no colon
   and no value (the prose-mention case) does not match. Implemented as
   one regex-per-field-alias pass over the section's lines (Python `re`,
   `re.IGNORECASE`), not a document-wide `in` check.
3. **TBD/unknown/blocked detection reads the captured value group**, not a
   fixed adjacent literal string. Once a field's value group is captured
   per (2), test *that captured string* (stripped, lower-cased) against
   `{"tbd", "unknown", "blocked", "n/a", "?"}` (exact match on the
   stripped value, plus a leading-substring check for
   `"tbd "`/`"unknown "`/`"blocked "` to tolerate `"TBD - waiting on intro"`).
   This is adjacency-robust by construction: it does not matter whether the
   label and "TBD" are separated by one space, two spaces, or a newline,
   because the value group was already isolated by the label-adjacency
   regex in (2), not by requiring a fixed literal string
   `"label: tbd"` to appear verbatim.
4. **Field-omission message and missing-value message stay distinct**
   (already true today, preserved): "field never appears in the section"
   vs. "field appears but its value is TBD/unknown/blocked."

This is a net-new, non-trivial regex/parsing addition — not something
`gate-lib` should absorb, since the field set, synonyms, and adjacency
tolerance are methodology-specific per rulebook (survey §2's gap line).

## 3. Mandatory test cases (added to every sales-*/tests/run-gate-tests.sh)

Fixing the test harness itself first is a precondition for trusting the new
cases: the single-quoted `bash -c "... '$actual_payload' ..."` construction
is replaced with passing the payload via a file or an exported variable
read with `printf '%s' "$VAR"` inside double-quoted `bash -c`, e.g.:

```bash
out="$(env $extra_env CLAUDE_PROJECT_DIR="$repo" TG_PAYLOAD="$actual_payload" \
  bash -c 'printf "%s" "$TG_PAYLOAD" | "$0"' "$GATE" 2>&1)"
```

so a fixture containing a literal `'` (added as its own required case
below) no longer corrupts the command.

Every sales-*/tests/run-gate-tests.sh must add, at minimum:
1. **Edit case** — old_string/new_string pair that, applied to an existing
   on-disk record, produces a passing document; asserts the gate reads the
   *reconstructed* result, not the on-disk original.
2. **MultiEdit case** — 2+ edits applied in order, at least one of which
   depends on a prior edit's result (ordering must matter to the assertion).
3. **`replace_all: true` case** — an Edit or MultiEdit edit whose
   `old_string` occurs more than once in the current content, asserting
   *every* occurrence is replaced before the field check runs (this is the
   exact bug the issue and gate-lib.py's `_apply_replace` both name).
4. **Malformed-JSON case** — payload is not valid JSON (or valid JSON but
   not an object, e.g. a bare array) → must deny (rc=2), not pass through.
5. **Kill-switch unrecognized-value case** — e.g.
   `SALES_QUALIFICATION_GATE_OFF=typo` → gate must stay **active** (rc
   reflects the normal check, not a bypass); a separate case keeps the
   existing recognized-on-spelling (`=1`) → bypass assertion, so both
   directions of the fixed kill-switch semantics are covered.
6. **Absolute-path case** — `file_path` given as an absolute path outside
   any `__ROOT__` substitution trick, resolved against `CLAUDE_PROJECT_DIR`,
   asserting the same allow/deny result as the equivalent relative path.
7. **Single-quote-in-payload case** — a fixture whose field value contains
   a literal `'` (e.g. `"Champion: Bob's team lead"`), asserting the
   harness itself survives (this is a harness self-test, not a gate-logic
   test — it is the regression test for defect 3 above).
8. **Section-scoping false-pass case (semantic upgrade regression test)**
   — a document where a field name is mentioned only in unrelated prose
   outside the qualification section (the issue's literal "competition"
   example) → must deny as missing, proving the substring-scan regression
   cannot silently return.
9. **Adjacency-tolerant TBD case** — the TBD marker on the line following
   its label (`"Economic Buyer:\nTBD"`) or with irregular spacing → must
   still deny as TBD, proving the label-adjacency/value-capture approach
   (not a fixed literal) is what is running.

All four plugins' suites must reach 100% pass (`전 스위트 green`) before
phase 2 is reported delivered; the delivery record must state the pass
count achieved.

## 4. README resync (issue defect 4)

Phase 2 rewrites each of the four sales-* plugin `README.md` files (plus
`sales/README.md` if it lists gate behavior) to describe: the actual
gate-lib-sourced trap/kill-switch/reconstruct behavior, the section-scoped
semantic check (not substring), the actual kill-switch env var name per
plugin, and the actual file paths present in the plugin directory today —
verified by a pass that greps every path/filename the README asserts
exists against the real tree, flagging any README-only ("ghost") file.

## 5. Sequencing and scope boundary

Phase 2 order: (a) re-verify core#72 is on `main`; (b) migrate all four
gates to gate-lib in one pass (mechanical, identical diff shape four
times — the shared contract is the gate-lib call sequence in §1, frozen
here); (c) implement the section/adjacency semantic upgrade per gate
(methodology-specific, not mechanical); (d) fix + extend all four test
harnesses per §3; (e) resync all READMEs per §4; (f) run all four suites
green and record the pass count in `docs/issue-13/reports/sales.md`.

Out of scope for issue-13: changing the *set* of required fields per
framework (MEDDPICC's 8 fields, BANT's 4) or the qualification-norms
methodology itself (issue-1's settled proposal) — this issue is a gate
implementation-quality remediation, not a methodology change.
