# sales-playbook

Enforces the sales role's playbook methodology: five required sections present, plus the marketing hand-off boundary (no inline messaging/positioning copy).

## Install

```
claude plugin marketplace add tokenmaxxxer/sales-rulebook
claude plugin install sales-playbook
```

## Layout

- `.claude-plugin/plugin.json` — plugin manifest.
- `hooks/hooks.json` — wires `playbook-gate.sh` to `PreToolUse` (Write|Edit|MultiEdit).
- `hooks/directive.sh` — sourceable fragment describing the playbook facet for the SessionStart banner (composed in by `sales/hooks/directive.sh`, not wired here).
- `hooks/playbook-gate.sh` — fail-closed gate requiring all five sections (process overview, qualification framework, ICP/persona, objection-handling, metrics) on `docs/issue-<n>/reports/sales.md`, and denying inline messaging-script/positioning-copy content.

Kill switch: `SALES_PLAYBOOK_GATE_OFF=1`.
