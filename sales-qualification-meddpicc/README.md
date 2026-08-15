# sales-qualification-meddpicc

Enforces the sales role's qualification-criteria methodology (docs/issue-1/proposals/methodology-norms.md (b) Qualification criteria), aligned to `roles/specs/sales.spec.json`'s 9-field MEDDPICC set (issue-22 spec-alignment): MEDDPICC is the default framework and **7 required fields** (Metrics, Economic Buyer, Decision Criteria, Decision Process, Identify Pain, Champion, and the spec's 9th field **Verdict**) must be present with a value or an explicit unknown/blocked marker — no required field may be silently omitted, per the phase-2 approval comment ("phase 2 반영: EB/Champion 외 MEDDPICC 전 필드 검사 추가") plus the issue-22 addendum adding `verdict`. **2 optional fields** (Paper Process, Competition — spec `required: false`) may be omitted entirely, but if either is declared it must still carry a value or explicit unknown/blocked/not-applicable marker rather than a bare label. BANT is accepted as a named fallback for short-cycle/simple deals. Economic Buyer and Champion must additionally be named individuals (not TBD) before an opportunity advances past initial qualification.

`Verdict` here is checked only for presence (a value or explicit
unknown/blocked marker), same as the other required fields — **not** the
spec's `recomputation` rule (verdict as a derived worst-case-completeness
value across the 8 substantive fields), which the spec itself marks
TBD/out-of-scope (issue-521 follow-up). The spec's `reference_resolution`
rule (economic_buyer/champion resolving to a named contact record) is
likewise named here but enforced by an external `role-spec-reference-guard.sh`
hook not present in this repo — this gate only checks that the fields carry
a value, not that the value resolves to a reference.

## Judgment notes (not gate-enforced)

A field's captured value should name the observable signal it rests on
(a public filing, a pricing page, a stated deadline, a direct quote
from the buyer) rather than stand as a bare label — a value with no
traceable basis carries the same qualification risk as a silent
omission, even though the gate above only checks presence. Economic
Buyer and Champion, once named, should also be placed in the context
of the deal's other identified buying-committee members (who else has
influence or access, and how the named individual's authority compares
to theirs) rather than recorded as an isolated name with no committee
context — a named Economic Buyer with no visibility into who else
influences the decision is only partially qualified.

## Gate mechanics (issue-13 phase 2)

`hooks/qualification-gate.sh` sources the shared gate-house library
(`core/hooks/lib/gate-lib.sh` / `gate-lib.py`, delivered by core issue #72)
rather than hand-rolling its own trap/kill-switch/JSON-parse/reconstruct
logic:

- The fail-closed EXIT trap and kill-switch check come from
  `gate_trap_fail_closed` / `gate_kill_switch_active`. Unrecognized
  kill-switch values (a typo, garbage) stay **active** — only a recognized
  on-spelling (`1`/`true`/`yes`/`on`, case-insensitive) disables the gate.
- Malformed or non-object JSON payloads are parsed via
  `gate_lib.gate_parse_json_or_deny`, which **denies** (rc=2) rather than
  passing through — a deliberate behavior change from a naive
  parse-or-exit-0 approach.
- Edit/MultiEdit reconstruction (including `replace_all`-aware replacement,
  applying every occurrence when requested rather than only the first) is
  done by `gate_lib.gate_reconstruct_write`, imported into the gate's
  embedded python3 payload via the `GATE_LIB_PY` env var the shell library
  exports.
- Path resolution against the project root uses `gate_lib.gate_normalize_path`
  for the pure string algebra; the gate itself still `realpath`s the root
  and keeps its own `CLAUDE_PROJECT_DIR`/git-toplevel root-detection logic,
  since root discovery is gate-specific, not part of the shared library.

## Semantic check (section-scoped, label-adjacent, value-capturing)

The qualification-field check is scoped to the qualification section only —
from the `framework_used: MEDDPICC` (or `BANT`) declaring line to the next
markdown heading of equal-or-higher level, or end of document. A field name
mentioned only in unrelated prose outside that section (e.g. "competition"
discussed in an unrelated paragraph five headings away) does not count as
present.

Within the scoped section, a field counts as present only when its label is
immediately adjacent to a captured value: `Label: value` on one line, or a
label line followed by its value on the next non-blank line (tolerating
markdown-list/table rendering). A bare mention of the field name with no
colon and no value does not count. TBD/unknown/blocked detection reads the
captured value itself (stripped, lower-cased) against
`{"tbd","unknown","blocked","n/a","?"}` plus a leading-substring match for
`"tbd "`/`"unknown "`/`"blocked "` (e.g. "TBD - waiting on intro") — this
works regardless of whether the label and value are on the same line, have
irregular spacing, or are on separate lines, because it operates on the
already-isolated captured value rather than a fixed literal string.

Field-omission ("field never appears in the section") and field-present-
but-TBD ("field appears but its value is TBD/unknown/blocked") remain
distinct deny messages.

## Install

```
claude plugin marketplace add tokenmaxxxer/sales-rulebook
claude plugin install sales-qualification-meddpicc
```

## Layout

- `.claude-plugin/plugin.json` — plugin manifest.
- `hooks/hooks.json` — wires the PreToolUse gate for Write/Edit/MultiEdit.
- `hooks/directive.sh` — sourceable fragment consumed by sales's composed SessionStart directive (not itself a hook).
- `hooks/qualification-gate.sh` — fail-closed PreToolUse gate enforcing the qualification-criteria checks above on `docs/issue-<n>/reports/sales.md`. Sources `core/hooks/lib/gate-lib.sh`/`gate-lib.py` (resolved via `CLAUDE_PLUGIN_ROOT_CORE`, falling back to `../../core` relative to this plugin) rather than reimplementing that machinery.
- `tests/run-gate-tests.sh` — disposable-repo test harness exercising allow/deny cases for the gate above.

## Kill switch

`SALES_QUALIFICATION_GATE_OFF=1` disables the gate. Any other value
(including empty/unset, a recognized off-spelling, or an unrecognized
typo) leaves the gate **active**.

## Running the tests

The test harness needs `CLAUDE_PLUGIN_ROOT_CORE` set to a checkout of
`tokenmaxxxer-core` (or a directory shaped like it) so the gate script's
`gate-lib.sh` source line resolves:

```
CLAUDE_PLUGIN_ROOT_CORE=/path/to/tokenmaxxxer-core/core \
  bash tests/run-gate-tests.sh
```
