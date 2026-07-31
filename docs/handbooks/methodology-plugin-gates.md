# sales methodology plugin gates and test harnesses

Four self-contained plugins (`sales-proposal-norm/`,
`sales-qualification-meddpicc/`, `sales-stage-definitions/`,
`sales-playbook/`) each carry one PreToolUse gate script under
`hooks/` and one test harness under `tests/run-gate-tests.sh`, per
`docs/issue-10/proposals/methodology-enforcement.md`.

Run any plugin's tests directly, no setup required:

    bash sales-proposal-norm/tests/run-gate-tests.sh
    bash sales-qualification-meddpicc/tests/run-gate-tests.sh
    bash sales-stage-definitions/tests/run-gate-tests.sh
    bash sales-playbook/tests/run-gate-tests.sh

Each harness spins up a disposable git-init repo per case, feeds a
stdin-JSON `Write` tool-call payload to the gate script, and asserts the
exit code (`0` = allow, `2` = deny) — the shape confirmed in
`implementation-rulebook/tests/run-gate-tests.sh` (referenced only, never
vendored, per `docs/handbooks/canon-scripts.md`).

- `proposal-norm-gate.sh` — targets `docs/issue-<n>/proposals/*sales*.md`;
  denies a write missing any of the six phase-1 sections. Kill switch
  `SALES_PROPOSAL_NORM_GATE_OFF=1`.
- `qualification-gate.sh` — targets `docs/issue-<n>/reports/sales.md`;
  under `framework_used: MEDDPICC`, checks all 8 fields individually (not
  just Economic Buyer/Champion — added per the issue #10 approval comment
  "EB/Champion 외 MEDDPICC 전 필드 검사 추가") and separately requires
  named Economic Buyer/Champion before advancement past initial
  qualification. Kill switch `SALES_QUALIFICATION_GATE_OFF=1`.
- `stage-definitions-gate.sh` — targets the same record path; requires
  `stage_count` in [5,7] and `exit_criteria_present` per stage, denies a
  rep-activity-verb stage name (keyword heuristic). Kill switch
  `SALES_STAGE_DEFINITIONS_GATE_OFF=1`.
- `playbook-gate.sh` — targets the same record path; requires all five
  playbook sections, denies inline messaging-script/positioning copy.
  Kill switch `SALES_PLAYBOOK_GATE_OFF=1`.

All four share the fail-closed shape confirmed independently in
`pricing-rulebook/pricing/hooks/methodology-gate.sh` and
`implementation-rulebook/coding/hooks/coding-progress-gate.sh`: `trap __fc
EXIT` at top, `CLAUDE_PROJECT_DIR`/git-root path resolution, full-content
reconstruction for Write/Edit/MultiEdit, a python3 judge wrapped in
try/except for fail-closed-on-internal-error, and a single missing-list
`deny()`. Each plugin's own `README.md` documents its Install/Layout.
