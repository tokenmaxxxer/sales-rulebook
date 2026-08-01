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
- `tests/run-gate-tests.sh` — disposable-repo test harness for the gate script.

## Gate behavior

`hooks/stage-definitions-gate.sh` sources the shared gate-house library
(core issue-72, `core/hooks/lib/gate-lib.sh` / `gate-lib.py`) for its
fail-closed EXIT trap, kill-switch check, JSON parsing, path
normalization, and Write/Edit/MultiEdit content reconstruction, rather
than hand-rolling that machinery itself. Only the stage-definitions
semantic check is local to this gate.

The semantic check is **structure-scoped**, not a whole-document
substring scan: it locates actual stage sections via markdown headings of
the form `## Stage N: <name>`, then:

- Counts detected stage sections — must be 5-7 (deny if fewer or more, or
  if none are found at all, e.g. stage-related words only appear in
  unrelated prose with no real headings).
- For each detected stage section, scopes the exit-criteria check to the
  text between that section's heading and the next, counting actual
  `- `/`* ` list items under an "Exit criteria" label — must be >=2 per
  stage (deny naming the specific stage that falls short).
- Verifies each stage section carries a named next-stage handoff via
  label-adjacent-value capture (`Next-stage handoff: <name>`, tolerating
  a `Label:\nvalue` split across lines) — deny if missing, or if the
  captured value is a placeholder (`tbd`, `unknown`, `blocked`, `n/a`,
  `?`, or a leading-substring match on those, case-insensitive).
- Denies if a stage name or exit criterion uses rep-activity phrasing
  (e.g. "had a call", "did a demo") instead of a completed buyer action
  in past tense.

Malformed or non-object JSON in the tool-call payload is denied (rc=2)
rather than silently passed through.

## Kill switch

`SALES_STAGE_DEFINITIONS_GATE_OFF` disables the gate only for a
recognized on-spelling: `1`, `true`, `yes`, or `on` (case-insensitive).
Any other value — unset, empty, a recognized off-spelling (`0`, `false`,
`no`, `off`), or an unrecognized/typo'd value — leaves the gate ACTIVE
(fail-closed default from the shared gate-house library).

## Running the tests

```
CLAUDE_PLUGIN_ROOT_CORE=/path/to/core sales-stage-definitions/tests/run-gate-tests.sh
```

`CLAUDE_PLUGIN_ROOT_CORE` must point at a checkout of core containing
`hooks/lib/gate-lib.sh` and `hooks/lib/gate-lib.py`; if unset, the gate
falls back to `<repo>/../core` relative to its own location.
