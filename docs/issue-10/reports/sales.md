loop_state: landed

## What was done

Implemented issue #10 phase 2 per the approved plugin-set design in
`docs/issue-10/proposals/methodology-enforcement.md` (Approved by
JiwonJung94, single-account mode, `APPROVE issue-10/sales`, with the
addendum "EB/Champion 외 MEDDPICC 전 필드 검사 추가"):

- **`sales-proposal-norm/`** (new plugin) — enforces the phase-1 (기획서)
  norm in full: `hooks/proposal-norm-gate.sh` denies a
  `docs/issue-<n>/proposals/*sales*.md` write missing any of the six
  required sections (status banner, scope, guiding principle, per-item
  breakdown, adoption rationale, plugin-reflection plan). Fail-closed
  (`trap __fc EXIT`), kill switch `SALES_PROPOSAL_NORM_GATE_OFF=1`,
  4/4 gate tests pass.
- **`sales-qualification-meddpicc/`** (new plugin) — enforces the
  qualification-criteria methodology: `hooks/qualification-gate.sh`
  requires `framework_used` (MEDDPICC or BANT, never a bare key); under
  MEDDPICC, checks all 8 fields (Metrics, Economic Buyer, Decision
  Criteria, Decision Process, Paper Process, Identify Pain, Champion,
  Competition) individually — not just EB/Champion, per the approval
  addendum — and denies if any is silently omitted; separately requires
  named (non-TBD) Economic Buyer and Champion before an opportunity
  advances past initial qualification. Kill switch
  `SALES_QUALIFICATION_GATE_OFF=1`, 6/6 gate tests pass (including the
  new "MEDDPICC missing Paper Process field" denial case and a BANT-record
  allow case confirming BANT records aren't held to MEDDPICC's 8-field
  check).
- **`sales-stage-definitions/`** (new plugin) — enforces the stage
  methodology: `hooks/stage-definitions-gate.sh` requires `stage_count` in
  [5,7], `exit_criteria_present` per stage, and denies a rep-activity-verb
  stage name/criterion (heuristic keyword list, not a full parse). Kill
  switch `SALES_STAGE_DEFINITIONS_GATE_OFF=1`, 6/6 gate tests pass.
- **`sales-playbook/`** (new plugin) — enforces the playbook methodology:
  `hooks/playbook-gate.sh` requires all five sections (process overview,
  qualification framework, ICP/persona, objection-handling, metrics) and
  denies inline messaging-script/positioning-copy content (the marketing
  hand-off boundary). Kill switch `SALES_PLAYBOOK_GATE_OFF=1`, 5/5 gate
  tests pass.
- **`sales/`** (thinned role-shell) — `hooks/directive.sh` now composes
  the four plugins' `hooks/directive.sh` fragments (sourced, fixed order
  proposal-norm → qualification → stages → playbook) into the SessionStart
  banner instead of encoding methodology depth inline;
  `hooks/record-fields-gate.sh` deleted (its three responsibilities moved
  to plugins 3 and 4's own gates, a more precise split than one file
  covering three unrelated deliverable shapes); `hooks/hooks.json` now
  registers only the SessionStart directive, no PreToolUse gate of its
  own.
- **`.claude-plugin/marketplace.json`** — registers all four new plugins
  alongside the existing `sales` entry, each independently sourced.
- **`README.md`** — Install section lists all five plugins (install only
  what a given issue's work touches); Layout section describes the
  composition and each plugin's gate/tests/kill-switch.

Every gate follows the fail-closed shape independently confirmed in two
sibling rulebooks (`pricing-rulebook/pricing/hooks/methodology-gate.sh`,
`implementation-rulebook/coding/hooks/coding-progress-gate.sh`), referenced
only, never copied: `trap __fc EXIT` at top, `CLAUDE_PROJECT_DIR`/git-root
path resolution, full-content reconstruction for Write/Edit/MultiEdit, a
python3 judge wrapped in try/except for fail-closed-on-internal-error, and
a single missing-list `deny()`. Each plugin's `tests/run-gate-tests.sh` is
a disposable-git-repo/stdin-JSON/exit-code-assertion harness in the shape
confirmed in `implementation-rulebook/tests/run-gate-tests.sh`.

## Why

The approver's "요구 정정" required the enforcement layer be a **plugin
set** (one independent plugin per methodology, at `freelunch`/`scout`'s
completeness bar), not one gate/directive deepened in place — see
`docs/issue-10/proposals/methodology-enforcement.md`'s guiding principle.
Building it that way, rather than one bundled `methodology-gate.sh`,
means each methodology (proposal norm / qualification / stages /
playbook) is independently installable, independently testable, and
independently killable, and a role working on only one deliverable kind
in a given issue doesn't need to install gates for the other two.

## Upstream basis

- `docs/issue-10/proposals/methodology-enforcement.md` — the approved
  phase-1 design this phase-2 work implements verbatim (plugin list,
  per-plugin breakdown, adoption rationale, plugin-reflection plan).
- `docs/issue-1/proposals/methodology-norms.md` (a)/(b)/(d) — the norm
  source each gate's required fields/sections trace back to.
- `pricing-rulebook/pricing/hooks/methodology-gate.sh`,
  `implementation-rulebook/coding/hooks/coding-progress-gate.sh`,
  `implementation-rulebook/tests/run-gate-tests.sh` — canon reference for
  gate/test shape (read, never copied, per core's canon-scripts.md).

## What did not work

Nothing required rework: each plugin's gate/test pair passed on first full
run after the build agents iterated locally against their own fixtures
before reporting back.

## Open findings

None blocking. Deferred to a future issue, noted here for traceability:
cross-plugin state tracking (e.g. a shared record of which of plugins 3-5
already ran on a given write) is not implemented, since the proposal found
no adopted norm that needs it — the one named order constraint
(Economic Buyer/Champion before advancement) resolves inside plugin 3's
single-write check.
