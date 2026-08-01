loop_state: landed

## What was done

Implemented issue #13 phase 2 per the approved remediation plan in
`docs/issue-13/proposals/2026-08-01-gate-a-plus-remediation.md` (approved
via `APPROVE issue-13/sales`, single-account mode, PR #14). Re-verified
core issue #72's shared gate-house library merged to `tokenmaxxxer-core`'s
`main` (`22a7cadef5c1389433d130bb4c9742863fbe47c0`, PR #74 MERGED) before
starting, per the proposal's precondition.

All four sales gate scripts now source `core/hooks/lib/gate-lib.sh` /
`gate-lib.py` (via `CLAUDE_PLUGIN_ROOT_CORE` with the documented
`../../core` fallback) instead of hand-rolling trap/kill-switch/JSON-parse/
path-normalize/Edit-MultiEdit-reconstruct logic:

- `sales-qualification-meddpicc/hooks/qualification-gate.sh`
- `sales-proposal-norm/hooks/proposal-norm-gate.sh`
- `sales-stage-definitions/hooks/stage-definitions-gate.sh`
- `sales-playbook/hooks/playbook-gate.sh`

Fixed per the issue's 2026-08-01 audit (grade A-): fail-open kill switch
on unrecognized value (now `gate_kill_switch_active`, fail-closed on any
unrecognized value), malformed-JSON pass-through (now
`gate_parse_json_or_deny`, denies rc=2), non-`replace_all`-aware
Edit/MultiEdit reconstruction (now `gate_reconstruct_write`,
`replace_all`-aware for both Edit and per-edit MultiEdit), and duplicated
absolute-path normalization (now `gate_normalize_path`).

Semantic checks upgraded in all four gates from whole-document substring
scan (`has_any()`) to section/heading-scoped, label-adjacent,
value-capturing matching, so a field/section name mentioned only in
unrelated prose no longer produces a false pass (the issue's "competition"
example), and TBD/unknown/blocked/placeholder detection reads the
captured value group (adjacency-robust: same-line, multi-space, or
next-line all detected) instead of a fixed literal substring.

Found and fixed two regressions during this delivery's own integration
pass, both in the "does this record document a X deliverable at all"
out-of-scope trigger, distinct from the (already fixed) per-field
detection:
- `sales-playbook/hooks/playbook-gate.sh` kept a whole-document substring
  fallback (`"playbook" not in new_text.lower()`) alongside its new
  heading-based detection, which reintroduced exactly the false-pass
  class this remediation exists to remove (this very record file tripped
  it, because it mentions `sales-playbook/...` file paths in prose).
  Removed the fallback; the gate now only recognizes a playbook
  deliverable via an actual markdown heading.
- `sales-qualification-meddpicc/hooks/qualification-gate.sh` had the same
  shape: `mentions_qual = has_any("qualification criteria", "meddpicc",
  "bant") or section is not None` — the `has_any(...)` half is a
  whole-document substring test (this record mentioning "MEDDPICC" by
  name, without ever declaring `framework_used:`, tripped it). Removed
  that half; the gate now only recognizes a qualification deliverable via
  an actual `framework_used:` declaration (the `section is not None`
  structural check alone).

`sales-proposal-norm` and `sales-stage-definitions` were checked and do
not have this pattern — both already gate purely on heading detection
with no whole-document substring fallback. Re-ran both fixed suites after
the changes: still 16/16 and 15/15 green respectively, and the full
four-suite run below reflects the post-fix state.

Each `tests/run-gate-tests.sh` fixed (the single-quote-breaking
`bash -c "... '$actual_payload' ..."` construction replaced with an
exported `TG_PAYLOAD` var + double-quoted `bash -c`) and extended with
the nine mandatory cases: Edit, MultiEdit, `replace_all`, malformed-JSON
(invalid + bare-array), kill-switch-unrecognized-value-stays-active,
absolute-path, single-quote-in-payload, section/structure-scoping
regression, and adjacency-tolerant TBD/placeholder.

All four plugin `README.md` files rewritten to describe the actual
gate-lib-sourced behavior, the real kill-switch env var per plugin, and
the actual section/adjacency semantic check — cross-checked every
referenced path/filename against the tree, no ghost-file references
found (the only paths not present in this repo, `gate-lib.sh`/`gate-lib.py`,
are correctly documented as the referenced core library, never vendored).

Work was fanned out to four background workers, one per plugin, against a
frozen contract (the gate-lib call sequence, the semantic-check algorithm
design, and the nine mandatory test cases, all specified in the approved
proposal) — the four gates share one mechanical shape but differ in field
set/section set per methodology, so each was independently producible
once the contract was frozen.

### Suite results (full delivery-state run, orchestrator-verified after both fixes)

| Plugin | Tests | Result |
|---|---|---|
| sales-qualification-meddpicc | 16 | 16 passed, 0 failed |
| sales-proposal-norm | 14 | 14 passed, 0 failed |
| sales-stage-definitions | 17 | 17 passed, 0 failed |
| sales-playbook | 15 | 15 passed, 0 failed |

**Total: 62 passed, 0 failed across all four suites — 전 스위트 green.**

### Core compliance-check.sh

Ran core canon's `core/hooks/tests/compliance-check.sh` (issue-72's
gate-house compliance detector) against each plugin's `hooks/` directory:

```
compliance-check: ok — sales-qualification-meddpicc/hooks/qualification-gate.sh
compliance-check: ok — sales-proposal-norm/hooks/proposal-norm-gate.sh
compliance-check: ok — sales-stage-definitions/hooks/stage-definitions-gate.sh
compliance-check: ok — sales-playbook/hooks/playbook-gate.sh
```

All four gates pass (exit 0): no hand-rolled kill-switch case statement
detected without `gate_kill_switch_active`, no `.replace(...)`-shaped
reconstruction detected without `gate_reconstruct_write`.

## Why

The issue graded the current implementation A- on four confirmed defects
(substring semantic matching, whitespace-brittle TBD detection, a
harness that breaks on a literal `'`, plus the generic fail-open
kill-switch/non-replace_all-aware/duplicated-normalize shapes gate-lib
was built to fix) and required all four sales gates raised to A+ by
reference-adopting core's shared library rather than re-fixing each bug
independently per gate — reimplementing any of trap/kill-switch/JSON-parse/
path-normalize/reconstruct locally after core#72 landed would itself be
the "자체 재구현" the issue's precondition forbids.

## Upstream basis

- `docs/issue-13/proposals/2026-08-01-gate-a-plus-remediation.md` — the
  approved phase-1 design this phase-2 work implements verbatim (gate-lib
  call sequence, semantic-check design, nine mandatory test cases, README
  resync scope).
- `docs/issue-13/reports/sales/current-state-survey.md` — the defect
  inventory (§3) and gate-lib interface read from core's worktree (§2)
  this phase-2 work implements against.
- `core/hooks/lib/gate-lib.sh` / `gate-lib.py` (tokenmaxxxer-core, merged
  `main` commit `22a7cadef5c1389433d130bb4c9742863fbe47c0`, issue-72 PR
  #74) — referenced, never copied.
- `core/hooks/tests/compliance-check.sh` — the core canon detector run
  against all four gates to confirm gate-lib adoption, not a local
  reimplementation.

## What did not work

Two integration defects, caught and fixed by the orchestrator's own
verification pass rather than shipping unnoticed: see the two
out-of-scope-trigger regressions described above under "What was done."
No other rework was required — the remaining test cases in all four
suites passed on the build workers' first reported runs, and the
orchestrator's independent re-run (with `CLAUDE_PLUGIN_ROOT_CORE` pointed
at the merged core tree) reproduced the same all-green result with no
further fixes needed beyond the two noted. One worker separately noted
the sandbox's Bash permission policy blocked `VAR=value command`
invocations referencing paths outside its own write scope during its own
local test runs, and worked around it with scratch-only scaffolding never
committed — did not affect the shipped gate script content.

## Open findings

None blocking. Deferred, noted here for traceability: the shared library
also exports `gate_bash_write_targets` (Bash-tool write-token scanning),
unused by any of the four sales gates since they only match
Write/Edit/MultiEdit tool calls today — out of scope for issue-13, noted
in case a future issue extends a sales gate to also watch Bash-tool
writes.
