# sales-qualification-meddpicc

Enforces the sales role's qualification-criteria methodology (docs/issue-1/proposals/methodology-norms.md (b) Qualification criteria): MEDDPICC is the default framework and **all 8 fields** (Metrics, Economic Buyer, Decision Criteria, Decision Process, Paper Process, Identify Pain, Champion, Competition) must be present with a value or an explicit unknown/blocked marker — no field may be silently omitted, per the phase-2 approval comment ("phase 2 반영: EB/Champion 외 MEDDPICC 전 필드 검사 추가"). BANT is accepted as a named fallback for short-cycle/simple deals. Economic Buyer and Champion must additionally be named individuals (not TBD) before an opportunity advances past initial qualification.

## Install

```
claude plugin marketplace add tokenmaxxxer/sales-rulebook
claude plugin install sales-qualification-meddpicc
```

## Layout

- `.claude-plugin/plugin.json` — plugin manifest.
- `hooks/hooks.json` — wires the PreToolUse gate for Write/Edit/MultiEdit.
- `hooks/directive.sh` — sourceable fragment consumed by sales's composed SessionStart directive (not itself a hook).
- `hooks/qualification-gate.sh` — fail-closed PreToolUse gate enforcing the qualification-criteria checks above on `docs/issue-<n>/reports/sales.md`.

## Kill switch

`SALES_QUALIFICATION_GATE_OFF=1` disables the gate.
