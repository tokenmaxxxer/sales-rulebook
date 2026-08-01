# sales-playbook

Enforces the sales role's playbook methodology: five required sections
present as actual markdown headings, plus the marketing hand-off boundary
(no inline messaging/positioning copy where it doesn't belong).

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
- `tests/run-gate-tests.sh` — disposable-repo test harness for the gate.

## Gate implementation (issue-13 remediation)

`hooks/playbook-gate.sh` sources the shared gate-house library from
`tokenmaxxxer-core` (issue #72) instead of hand-rolling its own
trap/kill-switch/JSON-parse/path-normalize/reconstruct machinery:

- The script's header sources
  `${CLAUDE_PLUGIN_ROOT_CORE:-<repo>/../../core}/hooks/lib/gate-lib.sh`,
  calls `gate_trap_fail_closed` for the fail-closed EXIT trap, and calls
  `gate_kill_switch_active` to evaluate the kill switch (unrecognized
  values now stay ACTIVE — only recognized on-spellings `1/true/yes/on`
  disable the gate).
- The embedded Python payload imports `gate-lib.py` (via
  `importlib.util` and the `GATE_LIB_PY` env var the shell library
  exports) and uses `gate_lib.gate_parse_json_or_deny` (malformed JSON or
  a non-object payload now denies, rc=2, rather than passing through),
  `gate_lib.gate_normalize_path` for path resolution, and
  `gate_lib.gate_reconstruct_write` to reconstruct the resulting document
  text for Write/Edit/MultiEdit — honoring `replace_all` for both a
  single Edit and each edit within a MultiEdit.
- Deny messages route through `gate_deny` (via a local `deny()` wrapper
  carrying the `sales:` role prefix).

## Semantic checks (structure-scoped, not substring)

The five required sections (process overview, qualification framework,
ICP/persona, objection-handling-and-competitive-notes, metrics) are
detected by matching actual markdown heading lines (`^#{1,6}\s+...`)
against each section's known aliases — a section name mentioned only in
unrelated prose, with no corresponding heading, does not satisfy the
requirement.

The marketing hand-off boundary (inline messaging-script/positioning-copy
detection) is scoped to the body of the objection-handling and metrics
sections plus any trailing prose after the last heading — not scanned
indiscriminately across the whole document — so a marketing-sounding
keyword appearing only in an unrelated or quoted aside elsewhere in the
document does not trigger a false deny.

Kill switch: `SALES_PLAYBOOK_GATE_OFF=1` (unrecognized values, including
typos, leave the gate active).

## Tests

```
CLAUDE_PLUGIN_ROOT_CORE=/path/to/tokenmaxxxer-core/core \
  bash tests/run-gate-tests.sh
```

15/15 cases pass as of the issue-13 phase-2 remediation, covering: the
happy path, missing-section deny, inline-messaging deny, both kill-switch
directions, foreign-path allow, Edit/MultiEdit/replace_all
reconstruction, malformed-JSON deny (including a bare-array payload),
absolute-path equivalence, a single-quote-in-payload harness survival
case, a structure-scoping regression test (section name in prose only),
and a marketing-boundary scoping regression test.
