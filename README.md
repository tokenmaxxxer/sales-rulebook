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

```
claude plugin marketplace add tokenmaxxxer/sales-rulebook
claude plugin install sales
```

Also install `tokenmaxxxer-core` alongside this plugin — it owns the commit-trailer,
record-field, and handbook-trigger gates (parameterized on `CLAUDE_ROLE`), the
role-directive boilerplate this role's `directive.sh` sources, and the
`warrant` hunt agent this role references. Without it, this role has no
gates and no hunt agent.

```
claude plugin marketplace add tokenmaxxxer/tokenmaxxxer-core
claude plugin install core
claude plugin install warrant
```

## Layout

- `sales/.claude-plugin/plugin.json` — plugin manifest
- `sales/hooks/hooks.json` — SessionStart wiring (PreToolUse gates are core canon now)
- `sales/hooks/directive.sh` — SessionStart role directive; a stub over core's
  `role-directive.sh` carrying only this role's own decides/use_when/produces/hand-off
- `sales/hooks/tests/stub-check.sh` — vendored copy of core's drift-recurrence
  check; run against `sales/` before treating a directive/gate change as done
- `sales/agents/warrant-hunter.md` — reference stub; the hunt agent itself is
  core's `warrant` plugin
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)

This is scaffolding, not a finished rulebook: fill in doctrine detail,
handoff enforcement, and any role-specific progress gate before treating
it as load-bearing.
