# issue-2 — implementation record

loop_state: landed

## What was done

Converted this rulebook's role-agnostic copies to core canon references, per
the approved proposal (`docs/issue-2/proposals/canon-reference-conversion.md`):

1. `sales/agents/warrant-hunter.md` replaced with a stub pointing at core's
   `warrant` plugin (`tokenmaxxxer-core` marketplace, core issue #63),
   preserving only this role's two unique facts (decision boundary, hand-off).
2. Deleted `sales/hooks/trailer-gate.sh`, `sales/hooks/handbook-trigger-gate.sh`,
   and `sales/hooks/record-fields-gate.sh` — all three are confirmed live in
   `core/hooks/hooks.json` (`tokenmaxxxer-core`, matcher `.*`), reading role
   identity from `CLAUDE_ROLE` at runtime. Removed their `PreToolUse` entries
   from `sales/hooks/hooks.json`, keeping only the `SessionStart` → `directive.sh`
   entry.
3. `sales/hooks/directive.sh` replaced with a stub that sources
   `core/hooks/lib/role-directive.sh` and calls `core_role_directive` with this
   role's four unique values (decides/use_when/produces/hand-off); all
   trap/kill-switch/case boilerplate removed.
4. `RECORD_FIELDS_TERMINAL_STATES` — no override added. Core's
   `record-fields-gate.sh` defaults to terminal state `landed`, which matches
   this repo's own usage; there is no role-level divergence to preserve.
5. Vendored `core/hooks/tests/stub-check.sh` into
   `sales/hooks/tests/stub-check.sh` (per that script's own header, every
   rulebook copies it verbatim) and ran it against `sales/`:

   ```
   $ bash sales/hooks/tests/stub-check.sh sales
   stub-check: ok — no vendored 'trailer-gate.sh' under sales
   stub-check: ok — no vendored 'record-fields-gate.sh' under sales
   stub-check: ok — no vendored 'handbook-trigger-gate.sh' under sales
   stub-check: ok — no vendored 'parse-check.sh' under sales
   stub-check: ok — sales/hooks/directive.sh is a role-directive stub
   ```

   Exit code 0 — PASS.

Also updated `README.md`'s Install/Layout sections to describe the three
converted files as core-canon references instead of locally-owned logic, and
to add install steps for `tokenmaxxxer-core` (`core` + `warrant` plugins).

## Why

Core issue #63 (warrant hunt agent) and core issue #66 (role-agnostic gates +
`role-directive.sh` boilerplate) landed a single canonical copy of this
machinery in `tokenmaxxxer-core`. This rulebook's own copies were confirmed
role-agnostic duplicates (own header comments said so, and core's live
versions are driven purely by `CLAUDE_ROLE`/`RECORD_FIELDS_TERMINAL_STATES`),
so keeping local copies is pure drift risk with no behavioral gain. This
conversion must land before this repo's rulebook-maturation phase 2 per the
issue's ordering constraint.

## Upstream basis

- Issue: #2 (this repo)
- Approved via: `APPROVE issue-2/implementation` (single-account mode)
- Verified directly against `tokenmaxxxer/tokenmaxxxer-core@main`:
  `core/hooks/hooks.json`, `core/hooks/trailer-gate.sh`,
  `core/hooks/record-fields-gate.sh`, `core/hooks/lib/role-directive.sh`,
  `core/hooks/tests/stub-check.sh`, `warrant/agents/warrant-hunter.md`,
  `.claude-plugin/marketplace.json`
- Proposal: `docs/issue-2/proposals/canon-reference-conversion.md`
- Survey: `docs/issue-2/reports/implementation/current-state-survey.md`

## Open findings

The proposal's open question #2 (whether `record-fields-gate.sh` should be
touched) is resolved: core's live `record-fields-gate.sh` is a generic §20
field-checker keyed on `CLAUDE_ROLE`, not this role's specific
`REQUIRED_FIELDS` list, so this role's copy is superseded entirely and was
deleted, not slimmed. No other open findings; all five issue items are
closed by this commit.
