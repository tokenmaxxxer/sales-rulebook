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
- `hooks/proposal-norm-gate.sh` — fail-closed gate: on any write to `docs/issue-<n>/proposals/*sales*.md`, requires all six sections (status banner, scope, guiding principle, per-item breakdown, adoption rationale, plugin-reflection plan), in order, to be present.
- `tests/run-gate-tests.sh` — disposable-repo test harness for the gate.

## Gate implementation (gate-lib-sourced)

The gate's mechanical scaffolding is sourced from `tokenmaxxxer-core`'s shared
gate-house library (`core/hooks/lib/gate-lib.sh` / `gate-lib.py`, issue #72)
rather than hand-rolled per plugin:

- **Fail-closed trap and kill switch** come from `gate_trap_fail_closed` and
  `gate_kill_switch_active`. The kill switch recognizes only the on-spellings
  `1`/`true`/`yes`/`on` (case-insensitive) as "disable the gate" — any other
  value, including an unrecognized typo, keeps the gate **active**.
- **JSON parsing** uses `gate_lib.gate_parse_json_or_deny`: malformed JSON, or
  a JSON value that isn't an object (e.g. a bare array), denies (`rc=2`)
  rather than silently passing the write through.
- **Path resolution** uses `gate_lib.gate_normalize_path` to resolve both
  relative and absolute `file_path` values against the detected project root
  (the root-detection logic itself — `CLAUDE_PROJECT_DIR` vs. `git
  rev-parse --show-toplevel` fallback — stays local to this gate).
- **Write/Edit/MultiEdit reconstruction** uses
  `gate_lib.gate_reconstruct_write`, which is `replace_all`-aware for both a
  single `Edit` and every edit in a `MultiEdit` list — the gate checks the
  document content that *would result* from the write, not the on-disk
  original.

## Semantic check: structure-scoped, not substring

The six required sections are located as actual markdown heading lines
(`^#{1,6}\s+...`), matched by regex synonym per section, not by a
whole-document substring scan — so a section name mentioned only in
unrelated prose (never as a heading) does not satisfy the requirement. The
status banner is the one exception (it is a `Status:` label/value line, not
a heading); its value is captured label-adjacent, tolerating the value
falling on the next non-blank line, but a heading line immediately following
the label does not count as its value. Once all six sections are located,
their positions in the document are checked to be non-decreasing — sections
present but out of order are denied separately from sections missing
entirely.

## Kill switch

Set `SALES_PROPOSAL_NORM_GATE_OFF=1` (or `true`/`yes`/`on`, case-insensitive)
to disable the gate. Any other value, including an unrecognized typo, leaves
the gate active.
