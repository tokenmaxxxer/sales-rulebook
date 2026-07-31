# Issue #1 — Phase-2 Record: `sales`

loop_state: landed

## What was done

Reflected the human-approved proposal
(`docs/issue-1/proposals/methodology-norms.md`, approved via the
`APPROVE issue-1/sales` issue comment) into the plugin:

1. `sales/hooks/directive.sh` — the `PRODUCES` string now names the three
   deliverable methodologies explicitly (MEDDPICC/BANT qualification
   criteria, 5-7 stage entry/exit-criteria stage definitions, the
   five-section sales playbook), not just the deliverable nouns.
2. `sales/hooks/record-fields-gate.sh` (new) — a role-owned PreToolUse
   addendum to core's generic §20 gate. On a write to this role's own
   record that documents a qualification-criteria or stage-definition
   deliverable, it requires `framework_used` (MEDDPICC | BANT),
   `stage_count`, and `exit_criteria_present` to be present.
3. `sales/hooks/hooks.json` — registers the new gate under `PreToolUse`
   for `Write|Edit|MultiEdit`, alongside the existing `SessionStart`
   directive entry.
4. `README.md` — documents the new gate file under "Layout."

## Why

Per the proposal's guiding principle: the proposal norm and deliverable
norm exist to make phase-1/phase-2 quality checkable by field presence,
not prose review — mirroring how core already gates the generic §20
record sections. The three sales-specific fields make the qualification-
framework and stage-definition methodology decisions (MEDDPICC default,
past-tense falsifiable exit criteria) mechanically checkable the same way.

## Upstream basis

- `docs/issue-1/proposals/methodology-norms.md` (d) Plugin-reflection plan
  — the approved scope for this phase.
- `docs/issue-1/reports/sales/current-state-survey.md` and
  `docs/issue-1/reports/sales/scout-brief.md` — the phase-1 evidence base
  the proposal was built against.
- Approval: issue #1 comment `APPROVE issue-1/sales` by `JiwonJung94`
  (an account listed in `docs/specs/approvers.md`), single-account mode
  per contract v3 s19.
- Verification performed this phase (not assumed from the proposal): read
  `tokenmaxxxer-core/core/hooks/record-fields-gate.sh` directly. It is a
  generic §20 section checker (what-was-done / why / upstream-basis /
  loop_state / open-findings) parameterized only by
  `RECORD_FIELDS_TERMINAL_STATES` — it has **no** per-role custom-field
  config surface. This confirms the proposal's flagged open question: the
  sales-specific fields (`framework_used`/`stage_count`/
  `exit_criteria_present`) cannot be added as config to core's existing
  engine and instead needed a small role-owned supplementary gate, which
  is what `sales/hooks/record-fields-gate.sh` is. Smoke-tested locally
  (pass case with all three fields present → rc=0; fail case missing all
  three → rc=2 with the expected refusal message).

## Scope not touched (per proposal (d) and the issue's own constraint)

- `sales/agents/warrant-hunter.md` — left as the existing core-canon
  reference stub; not touched, per the issue's explicit constraint.
- No qualification-criteria/stage-definition/playbook *content* was
  authored — the proposal scoped that as separate downstream deliverable
  work, not this plugin-reflection phase.
- Core's own `record-fields-gate.sh` was read for verification but not
  modified — it is core canon, out of this role's write scope.

## Open findings

None blocking. One item flagged in the proposal as an open question is
now resolved (see "Upstream basis" above): core's gate has no per-role
field-config surface, so this phase added a role-owned gate rather than
config. No further open findings.
