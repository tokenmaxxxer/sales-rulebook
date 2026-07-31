# Issue #1 — Current-State Survey (sales)

Scope: what this repo's `sales` plugin and phase-1/phase-2 conventions look like
today, as the base the proposal in `docs/issue-1/proposals/` builds against.

## Role definition (README.md, directive.sh)

- decides: 리드/기회를 어떻게 진행시킬지
- use_when: 영업 프로세스 설계가 걸릴 때
- produces: **sales playbook, stage definitions, qualification criteria**
- hand-off: 메시지/포지셔닝 자체는 → marketing
- `write_scope: []` in README.md front matter — currently empty/unspecified

`produces` already names three deliverable kinds. No methodology or required
components are attached to any of them yet — this is exactly the gap issue #1
asks to close.

## Plugin structure

- `sales/hooks/directive.sh` — thin wrapper sourcing core's
  `role-directive.sh`, passing only role-specific strings (decides/use_when/
  produces/hand-off). No sales-specific gate logic lives here.
- `sales/agents/warrant-hunter.md` — reference stub to core's `warrant` plugin
  (core issue #63). No local agent.
- `sales/hooks/tests/run-stub-check.sh` — thin wrapper over core's
  `stub-check.sh` drift check.
- No `record-fields` gate or config exists in this plugin yet. Core owns the
  generic trailer/record-field/handbook-trigger gates (per README.md and
  `docs/issue-2/proposals/canon-reference-conversion.md`); this role has not
  yet parameterized any of them with sales-specific required fields.

## Phase-1/phase-2 precedent in this repo (issue-2, issue-5)

Both prior issues (`docs/issue-2/`, `docs/issue-5/`) use the same phase-1
shape this proposal should follow:
- `docs/issue-<n>/reports/<role>/` (or `.../implementation/`) — current-state
  survey, written before the proposal.
- `docs/issue-<n>/proposals/<slug>.md` — proposal document with: a status
  banner ("proposal only, phase 1"), a guiding principle, and a
  per-item breakdown (what changes, why, illustrative target shape).
- Proposals reference core canon rather than embedding/copying its logic
  (mirrors this issue's constraint: warrant-hunter stays a core reference).

No existing per-role document defines *methodology or required components*
for phase-1 proposals or phase-2 deliverables in general — issue #1 is the
first to establish that norm, scoped to `sales`.

## Gaps this proposal must close

1. No qualification-criteria methodology is named (produces item 3).
2. No stage-definition methodology or exit-criteria discipline is named
   (produces item 2).
3. No sales-playbook required-component list is named (produces item 1).
4. No phase-1 proposal norm (methodology + required sections + evidence
   format) is written down anywhere in this repo, sales or core.
5. No plan exists for how any of the above becomes enforceable (directive
   text, `record-fields` required keys, or a gate) rather than just prose.
