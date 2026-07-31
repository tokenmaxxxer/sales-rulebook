# sales-rulebook

Rulebook for the `sales` role (contract v3 role-handoff protocol), split off
per `docs/issue-160/proposals/role-taxonomy.md`'s round-3 promotion and
generated as skeleton scaffolding by issue-170.

- **decides**: 리드/기회를 어떻게 진행시킬지
- **use_when**: 영업 프로세스 설계가 걸릴 때
- **produces**: sales playbook, stage definitions, qualification criteria
- **write_scope**: []
- **hand-off**: 메시지/포지셔닝 자체는 → marketing

## Install

This rulebook is a **plugin set**, not one bundled plugin: one independent
plugin per adopted methodology (per
`docs/issue-10/proposals/methodology-enforcement.md`), at the same
completeness bar as core's `freelunch`/`scout` plugins. Install `sales`
plus whichever methodology plugins the work touches — a role working only
on stage definitions in a given issue only needs `sales` +
`sales-stage-definitions`, not all four.

```
claude plugin marketplace add tokenmaxxxer/sales-rulebook
claude plugin install sales
claude plugin install sales-proposal-norm
claude plugin install sales-qualification-meddpicc
claude plugin install sales-stage-definitions
claude plugin install sales-playbook
```

Also install `tokenmaxxxer-core` alongside this plugin set — it owns the
commit-trailer, record-field, and handbook-trigger gates (parameterized on
`CLAUDE_ROLE`), the role-directive boilerplate `sales/hooks/directive.sh`
sources, and the `warrant` hunt agent this role references. Without it,
this role has no core gates and no hunt agent.

```
claude plugin marketplace add tokenmaxxxer/tokenmaxxxer-core
claude plugin install core
claude plugin install warrant
```

## Layout

- `sales/` — role-shell (thin): identity, hand-off, composes the four
  methodology plugins below into one SessionStart directive.
  - `.claude-plugin/plugin.json` — plugin manifest
  - `hooks/hooks.json` — SessionStart wiring only; methodology PreToolUse
    gates live in their own plugins, not here
  - `hooks/directive.sh` — sources core's `role-directive.sh` for the
    decides/use_when/hand-off boilerplate, plus the four methodology
    plugins' `hooks/directive.sh` fragments (proposal-norm -> qualification
    -> stages -> playbook, fixed order) for the PRODUCES/USE_WHEN facets
  - `hooks/tests/run-stub-check.sh` — thin wrapper referencing core's
    drift-recurrence check (`core/hooks/tests/stub-check.sh`); run before
    treating a directive/gate change as done — never vendor the check itself
  - `agents/warrant-hunter.md` — reference stub; the hunt agent itself is
    core's `warrant` plugin
- `sales-proposal-norm/` — phase-1 (기획서) norm in full: six required
  proposal sections, gate (`hooks/proposal-norm-gate.sh`), tests, kill
  switch `SALES_PROPOSAL_NORM_GATE_OFF=1`
- `sales-qualification-meddpicc/` — qualification-criteria methodology:
  MEDDPICC default (all 8 fields checked, none silently omitted) / BANT
  fallback, Economic Buyer + Champion required before advancement, gate
  (`hooks/qualification-gate.sh`), tests, kill switch
  `SALES_QUALIFICATION_GATE_OFF=1`
- `sales-stage-definitions/` — stage-definitions methodology: 5-7 stages,
  >=2 falsifiable past-tense exit criteria per stage, gate
  (`hooks/stage-definitions-gate.sh`), tests, kill switch
  `SALES_STAGE_DEFINITIONS_GATE_OFF=1`
- `sales-playbook/` — sales-playbook methodology: five required sections,
  marketing hand-off boundary, gate (`hooks/playbook-gate.sh`), tests, kill
  switch `SALES_PLAYBOOK_GATE_OFF=1`
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)

Each methodology plugin is self-contained (own manifest, gate, tests, kill
switch) and independently installable/testable — the phase-2 (산출물) norm
is the composition of the three PRODUCES plugins, the phase-1 (기획서) norm
is `sales-proposal-norm` alone. See
`docs/issue-10/proposals/methodology-enforcement.md` for the full
composition design.
