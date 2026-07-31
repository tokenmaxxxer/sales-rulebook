# sales-stage-definitions

Enforces the sales role's stage-definitions methodology (docs/issue-1/proposals/methodology-norms.md (b) Stage definitions): 5-7 stages, >=2 falsifiable past-tense exit criteria per stage, named next-stage handoff.

## Install

```
claude plugin marketplace add tokenmaxxxer/sales-rulebook
claude plugin install sales-stage-definitions
```

## Layout

- `.claude-plugin/plugin.json` — plugin manifest.
- `hooks/hooks.json` — wires the PreToolUse gate for Write|Edit|MultiEdit.
- `hooks/directive.sh` — sourceable fragment consumed by `sales/hooks/directive.sh` for the SessionStart banner; not wired as a standalone hook here.
- `hooks/stage-definitions-gate.sh` — fail-closed PreToolUse gate that enforces stage-definitions shape on `docs/issue-<n>/reports/sales.md`.

## Kill switch

`SALES_STAGE_DEFINITIONS_GATE_OFF=1` disables the gate.
