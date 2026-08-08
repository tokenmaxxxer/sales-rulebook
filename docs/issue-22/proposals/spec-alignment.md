---
status: proposed
files:
  - sales-qualification-meddpicc/README.md
  - sales-qualification-meddpicc/hooks/qualification-gate.sh
  - sales-qualification-meddpicc/hooks/directive.sh
  - sales-qualification-meddpicc/tests/run-gate-tests.sh
  - sales-stage-definitions/README.md
  - sales-stage-definitions/hooks/stage-definitions-gate.sh
  - sales-stage-definitions/hooks/directive.sh
  - sales-stage-definitions/tests/run-gate-tests.sh
  - docs/handbooks/methodology-plugin-gates.md
---

## Request

Align this rulebook's vocabulary and rules with `roles/specs/sales.spec.json`
(on-the-record, MEDDPICC-sourced) — layer the spec's 9 required deliverable
fields and 5-word loop_state vocabulary onto existing docs/hooks, strengthening
current content, never deleting methodology. Phase 1 only: map each spec field
onto existing rulebook concepts and name exactly which docs/hooks change.

## Constraints

- Never delete existing methodology content; extend only.
- No new dependency, no new plugin — work inside the 4 existing sales-* gate
  plugins plus the shared handbook.
- `verdict` recomputation enforcement and `reference_resolution`
  (economic_buyer/champion → named contact) are marked TBD/out-of-scope by
  the spec itself (issue-521 follow-up) — this proposal adds the vocabulary
  these rules reference, not their enforcement machinery.
- Acceptance requires the rulebook's loop_state vocabulary match the spec's
  5-word set exactly (no stale/extra words) — this only binds a *new*
  deal-progression vocabulary this proposal introduces in
  `sales-stage-definitions`; it does not touch core's unrelated
  report-frontmatter `loop_state` field (different concept, same field name
  by coincidence — see Rationale).

## Rationale

**Where to enforce `verdict`:** considered adding it as a new standalone
9th check in `sales-qualification-meddpicc/hooks/qualification-gate.sh`
alongside the existing 8 `MEDDPICC_FIELDS`. Rejected a separate new gate
plugin for it — the spec's own `recomputation` rule says verdict must never
be a standalone summary field, only a derived worst-case-completeness value,
and that derivation is explicitly TBD/out-of-scope per issue-521. Building a
new plugin now for a field whose semantics are still undefined would lock in
a shape likely to be rewritten once the follow-up lands. Chosen: add
`verdict` to the existing field-presence check (must be a value or explicit
unknown/blocked marker, same as the other 8) inside the plugin that already
owns MEDDPICC field parsing, and leave true recomputation for the follow-up
issue.

**Where to place loop_state vocabulary:** considered overloading core's
existing report-frontmatter `loop_state` (already present on every
`docs/issue-<n>/reports/sales.md`) with the spec's 5 deal-progression words.
Rejected — core's `loop_state` is a record-workflow state (per contract v3
§2, values like `landed`/`open`/`cleared` describe the *report's* delivery
status) and is mechanically checked against a *different*, contract-owned
terminal-state list; conflating it with deal-stage semantics would break
that mechanical check and confuse two unrelated concepts sharing one field
name. Chosen: `sales-stage-definitions` — the only plugin that already
regulates deal-stage progression (`## Stage N: <name>` headings) — gains a
fixed-vocabulary check requiring the deliverable's declared MEDDPICC deal
state to be drawn from the spec's 5 words, kept explicitly distinct from
(and cross-referenced against) core's report-frontmatter `loop_state` so the
name collision doesn't get silently conflated in future edits.

**Optional fields (`paper_process`, `competition`):** considered leaving all
8 fields equally required, as today. Rejected — the spec explicitly marks
these two `required: false`, and silently keeping the stricter rule would
contradict the spec instead of aligning to it. Chosen: relax exactly these
two to "present or explicitly marked not-applicable," keep the other 6 (plus
new `verdict`) required.

## What will be done

1. `sales-qualification-meddpicc/hooks/qualification-gate.sh`: add `verdict`
   (qualified/disqualified) as a 9th checked field, same presence rule as the
   others (value or explicit unknown/blocked marker — not full recomputation
   enforcement, per Constraints). Relax `paper_process` and `competition` to
   optional per spec `required: false`.
2. `sales-qualification-meddpicc/README.md` + `hooks/directive.sh`: document
   the 9th field and the two-field optionality split; note the
   `reference_resolution` and `recomputation` spec rules as named-but-external
   / named-but-TBD respectively, so the vocabulary is present even where
   enforcement isn't (Acceptance's "every field name appears" check covers
   `verdict` too).
3. `sales-qualification-meddpicc/tests/run-gate-tests.sh`: add cases covering
   `verdict` presence/absence and the relaxed optional-field behavior.
4. `sales-stage-definitions/hooks/stage-definitions-gate.sh`: introduce a
   `Deal state: <value>` label (analogous to the gate's existing
   `Next-stage handoff: <name>` label-adjacent-value capture) as the
   declaration point for the deal's current MEDDPICC loop_state, and add a
   fixed-vocabulary check on that captured value — must be one of
   `qualifying`, `negotiating`, `landed`, `economic-buyer-undeclared`,
   `deal-unreachable` (spec's exact 5-word set) — alongside the existing
   free-form `## Stage N: <name>` structural check (kept, not replaced:
   stage names/count/exit-criteria rules are unrelated methodology and stay
   as-is).
5. `sales-stage-definitions/README.md` + `hooks/directive.sh`: document the
   5-word loop_state vocabulary, and explicitly note it is a distinct concept
   from core's report-frontmatter `loop_state` field despite the shared name.
6. `sales-stage-definitions/tests/run-gate-tests.sh`: add cases for each of
   the 5 accepted words and a rejection case for a stale/unlisted word.
7. `docs/handbooks/methodology-plugin-gates.md`: cross-reference the spec
   (`roles/specs/sales.spec.json`) as the source of truth for the 9-field
   list and 5-word loop_state set, so future edits touch the right place.

## Out of scope

- `verdict` recomputation logic (worst-case completeness across 8 fields) —
  spec-marked TBD, issue-521 follow-up.
- `reference_resolution` structural enforcement (named-contact resolution
  for economic_buyer/champion) — spec assigns this to an external
  `role-spec-reference-guard.sh` hook not present in this repo.
- Any change to core's report-frontmatter `loop_state` field or its
  terminal-state gate — untouched, different concept.
- `sales-playbook` and `sales-proposal-norm` — surveyed, confirmed
  unrelated to MEDDPICC fields or loop_state (structural-section checks
  only).

## How you'll know it worked

- `grep -ri '<field>' docs/ README.md sales-qualification-meddpicc/` finds
  every one of the 9 spec field names (metrics, economic_buyer,
  decision_criteria, decision_process, paper_process, identify_pain,
  champion, competition, verdict) after phase 2.
- `grep -rn 'qualifying\|negotiating\|landed\|economic-buyer-undeclared\|deal-unreachable' sales-stage-definitions/` finds all 5 spec loop_state words, and no other deal-stage word is asserted as valid in that gate.
- `sales-qualification-meddpicc/tests/run-gate-tests.sh` and
  `sales-stage-definitions/tests/run-gate-tests.sh` pass with the new cases.
