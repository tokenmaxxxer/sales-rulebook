# Issue #2 — Current-State Survey (Phase 1: research)

Subject: issue-160/2 — "core canon reference conversion: remove warrant-hunter / gate
copies (core #63/#66 rollout)". This is a survey only; no changes are made here.

## 1. Where the content currently lives

All of the content in scope was added in a single seed commit,
`260ded3 Seed rulebook skeleton for role sales (on-the-record issue-170)`. That commit
introduced this full file set:

```
.claude-plugin/marketplace.json
README.md
docs/specs/approvers.md
sales/.claude-plugin/plugin.json
sales/agents/warrant-hunter.md
sales/hooks/directive.sh
sales/hooks/handbook-trigger-gate.sh
sales/hooks/hooks.json
sales/hooks/record-fields-gate.sh
sales/hooks/trailer-gate.sh
```

There is no `core/` checkout, submodule, or canon repo present in this working tree.
The issue body and the in-file comments both reference an external "core" repo
(`core issue #63` for the `warrant/` plugin, `core issue #66` for the three role-agnostic
gates, `core/hooks/lib/role-directive.sh`'s `core_role_directive` function) as the
landing place for canon, but that repo's actual contents are not checked out here and
were not inspected as part of this survey — the proposal below treats core's paths as
given by the issue text, not as verified file contents.

## 2. File-by-file classification

| File | Nature | Notes |
|---|---|---|
| `sales/agents/warrant-hunter.md` | **Full duplicate-of-canon shell, with role-unique payload inline** | Header explicitly says "adapted from implementation-rulebook's `agents/warrant-hunter.md`". The generic mandate/scope/stance-rotation prose is a copy of another role's copy of the same agent description (i.e. a copy of a copy, not sourced from core `warrant/`). The only role-unique content is: the decision boundary line (`리드/기회를 어떻게 진행시킬지`) and the hand-off line (`메시지/포지셔닝 자체는 → marketing`). |
| `sales/hooks/directive.sh` | **Boilerplate + role-unique payload, not yet using a shared function** | Implements the SessionStart directive by hand (trap/set -uo pipefail/case/heredoc) rather than sourcing `core/hooks/lib/role-directive.sh`'s `core_role_directive` function, which the issue says already exists in core. The heredoc body (YOU DECIDE / USE_WHEN / PRODUCES / WRITE_SCOPE / HAND-OFF / BOUNDARY CASE / RECORD lines) is genuinely role-specific data, but the surrounding shell scaffolding (trap, kill-switch, role-guard, heredoc mechanics) duplicates logic that item 3 of the issue says should live in the shared function. |
| `sales/hooks/handbook-trigger-gate.sh` | **Duplicate copy, explicitly a placeholder** | Comment says "contract v3 s21, handbook half" — one of the three role-agnostic gates the issue's item 2 names. File body is a role-agnostic fail-closed skeleton (`exit 0 # placeholder verdict`) with no sales-specific logic; the `SALES_CYCLE_OFF` kill-switch var name is the only role-specific token. |
| `sales/hooks/record-fields-gate.sh` | **Genuinely role-unique, not a copy candidate for removal per se** | Comment says "adapted per issue-170 from roles/sales.json's `produces`, NOT copied from another role's field set". `REQUIRED_FIELDS = ["sales-playbook", "stage-definitions", "qualification-criteria"]` and the `docs/issue-<n>/reports/sales.md` target path are sales-specific. This is the field-presence half of s20/s21 record-fields enforcement — the issue's item 4 calls out that role-specific *differences* (it gives `RECORD_FIELDS_TERMINAL_STATES` as an example) should be preserved via config, implying the surrounding gate mechanics are meant to move to core while the field list/config stays local. |
| `sales/hooks/trailer-gate.sh` | **Duplicate copy, explicitly role-agnostic** | Comment: "Adapted from implementation-rulebook's trailer-gate.sh, role name substituted only (this file's logic is role-agnostic)." Only the `deny()` message prefix (`"sales: refused"`) and `SALES_CYCLE_OFF` var name are role-specific tokens; the trailer-parsing/subject-check logic is byte-for-byte portable. One of the three gates named in issue item 2. |
| `sales/hooks/hooks.json` | **Registration wiring for the three duplicated gates + directive** | Registers `directive.sh` on SessionStart, `record-fields-gate.sh` on PreToolUse (Write/Edit/MultiEdit/NotebookEdit), and `handbook-trigger-gate.sh` + `trailer-gate.sh` on PreToolUse (Bash). Per issue item 2, the hook *registration* for the three role-agnostic gates is meant to be removed here because core's own hook registration (core issue #66) takes over; `record-fields-gate.sh`'s registration is role-owned and stays. |
| `sales/.claude-plugin/plugin.json` | Not in scope | Plugin manifest identity metadata; issue's 5 items don't touch it. |
| `.claude-plugin/marketplace.json` | Not in scope | Marketplace listing; unaffected by canon conversion. |
| `README.md` | **Indirectly in scope** | "Layout" section documents/describes `warrant-hunter.md`, `trailer-gate.sh`, `handbook-trigger-gate.sh` as if they are files owned by this repo. Needs updating once those become references/stubs so the README doesn't claim ownership of content that now lives in core. |
| `docs/specs/approvers.md` | Not in scope | Approve-authority allowlist for phase-2 gating; unrelated to canon/gate duplication. |

## 3. Mapping to the issue's 5 work items

1. **Remove warrant-hunter copy, replace with core canon reference**
   Target: `sales/agents/warrant-hunter.md`. Currently a full copy-of-a-copy (see row
   above). No existing reference/stub pattern exists elsewhere in this repo to model
   after — this repo has never referenced an external canon file before.

2. **Remove trailer-gate.sh / record-fields-gate.sh / handbook-trigger-gate.sh copies
   and their hook registrations; core's registration replaces them**
   - `trailer-gate.sh` and `handbook-trigger-gate.sh` are the two of these three that
     are confirmed role-agnostic copies (both say so in their own header comments) —
     clean removal candidates.
   - `record-fields-gate.sh` is *not* a role-agnostic copy — it is role-owned config
     wrapped in shared gate mechanics. The issue's phrasing "removed... core's
     registration replaces them" groups it with the other two, but its content
     (REQUIRED_FIELDS, target path) is sales-specific and must survive the
     conversion in some form (see item 4 below and the proposal).
   - Registrations for all three currently live in `sales/hooks/hooks.json`.

3. **Replace directive.sh with a stub sourcing the shared function**
   Target: `sales/hooks/directive.sh`. Currently hand-rolls scaffolding that
   duplicates `core_role_directive`'s job. Role-unique payload = the heredoc body
   (YOU DECIDE / USE_WHEN / PRODUCES / WRITE_SCOPE / HAND-OFF / BOUNDARY CASE / RECORD
   lines) plus the `SALES_CYCLE_OFF` kill-switch name.

4. **Preserve real role-level differences via explicit config (e.g.
   `RECORD_FIELDS_TERMINAL_STATES`)**
   No terminal-states config exists yet in this repo (no loop-state handling appears
   in any of the seed files) — this item is forward-looking against whatever core's
   `record-fields-gate` canon exposes as configurable. The closest existing analog is
   `record-fields-gate.sh`'s own `REQUIRED_FIELDS` list, which is exactly the kind of
   role-local override the issue is describing.

5. **Confirm `core/hooks/tests/stub-check.sh` passes, record it**
   No such test file, or any test infrastructure, exists in this repo currently. This
   is entirely a core-repo-side artifact; this repo has nothing to survey for it
   beyond noting it doesn't exist locally.

## 4. Summary of duplicate vs. unique split

- **Pure duplicate, safe to fully replace with a reference/stub**: `trailer-gate.sh`,
  `handbook-trigger-gate.sh`, most of `warrant-hunter.md`'s prose, and the
  general-purpose shell scaffolding inside `directive.sh`.
- **Role-unique, must be preserved (in config or a role-owned section) through the
  conversion**: the decision-boundary/use_when/produces/write_scope/hand-off lines in
  `warrant-hunter.md` and `directive.sh`'s heredoc; `record-fields-gate.sh`'s
  `REQUIRED_FIELDS` list and target path; the `SALES_CYCLE_OFF` kill-switch name used
  throughout.
- **Registration-only, to be dropped in favor of core-side registration**: the three
  gate entries in `sales/hooks/hooks.json`'s `PreToolUse` block (SessionStart's
  `directive.sh` entry stays, since directive becomes a stub, not a removal).
