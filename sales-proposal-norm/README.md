# sales-proposal-norm

Enforces the sales role's phase-1 proposal norm (`docs/issue-1/proposals/methodology-norms.md` (a)): six required sections, in order, on any sales phase-1 proposal write.

## Install

```
claude plugin marketplace add tokenmaxxxer/sales-rulebook
claude plugin install sales-proposal-norm
```

This plugin composes into the `sales` role-shell (its `directive.sh` fragment is sourced into the role's SessionStart banner), but it is independently installable and independently testable — it does not require the `sales` role-shell plugin to run its own tests.

## Layout

- `.claude-plugin/plugin.json` — plugin manifest.
- `hooks/hooks.json` — wires `proposal-norm-gate.sh` as a `PreToolUse` hook on `Write|Edit|MultiEdit`.
- `hooks/directive.sh` — sourceable fragment (not a standalone hook) defining `SALES_PROPOSAL_NORM_FRAGMENT`, composed by `sales/hooks/directive.sh` into the session banner.
- `hooks/proposal-norm-gate.sh` — fail-closed gate: on any write to `docs/issue-<n>/proposals/*sales*.md`, requires all six sections (status banner, scope, guiding principle, per-item breakdown, adoption rationale, plugin-reflection plan) to be present.
- `tests/run-gate-tests.sh` — disposable-repo test harness for the gate.

## Kill switch

Set `SALES_PROPOSAL_NORM_GATE_OFF=1` to disable the gate.
