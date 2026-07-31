# Issue #2 — Proposal: Convert to Core Canon References

Status: **proposal only, phase 1**. No canon files, gate copies, or directives are
edited by this document or by this phase. Execution is phase 2, gated on human
Approve per contract v3 s19. This proposal is scoped against the current-state survey
at `docs/issue-2/reports/implementation/current-state-survey.md`.

## Guiding principle

Every file below currently mixes two things: (a) generic mechanics that core issue
#63/#66 have landed a single canonical copy of, and (b) role-sales-specific data
(decision boundary, hand-off target, required record fields, kill-switch name). The
conversion should delete (a) in favor of a reference to core, and keep (b) inline,
as small and explicit as possible — ideally as data/config rather than re-implemented
logic.

## Item 1 — `sales/agents/warrant-hunter.md`

**Proposal**: replace the file's body with a short stub that:
- States this role has no local warrant-hunter agent definition; the hunt agent is
  core's `warrant/` plugin (core issue #63, size-proportional budget + miss-streak +
  instrumentation).
- Points to the core plugin path/reference (exact core path TBD — not verified from
  this repo; phase 2 should confirm the actual path core issue #63 landed at before
  writing the reference).
- Preserves only the two role-unique facts currently embedded in this file:
  - decision boundary: `리드/기회를 어떻게 진행시킬지`
  - hand-off: `메시지/포지셔닝 자체는 → marketing`
  These are already duplicated in `directive.sh`'s heredoc and in `README.md`'s
  "decides"/"hand-off" bullets, so the stub can simply reference those rather than
  restate the same Korean strings a third time — reducing future drift risk.
- Drops the generic "Mandate / Stances rotate per invocation / Scope: Reads only"
  prose entirely — that's core's canon content now, not this repo's to maintain.

Concrete target shape (illustrative, not final wording):

```markdown
# sales warrant-hunter

This role uses core's `warrant/` plugin (core issue #63) for background hunting.
No role-local hunt agent is defined here.

Role-specific inputs the core agent consumes for this role:
- decision boundary: 리드/기회를 어떻게 진행시킬지 (see README.md "decides")
- hand-off: 메시지/포지셔닝 자체는 → marketing (see README.md "hand-off")
```

## Item 2 — `trailer-gate.sh`, `record-fields-gate.sh`, `handbook-trigger-gate.sh`

These three are not uniform — the survey found only two of the three are pure
role-agnostic copies.

- **`sales/hooks/trailer-gate.sh`** — delete outright. Its own header comment
  confirms the logic is role-agnostic ("role name substituted only"). Core issue #66
  registers this gate centrally; no stub is needed in this repo, only removal of the
  file and its `hooks.json` entry.
- **`sales/hooks/handbook-trigger-gate.sh`** — delete outright, same reasoning; the
  file body is already a role-agnostic placeholder (`exit 0 # placeholder verdict`)
  with no sales-specific logic beyond the `SALES_CYCLE_OFF` kill-switch var name,
  which core's centralized version presumably parameterizes via `CLAUDE_ROLE` already
  (per the issue background: "CLAUDE_ROLE 주입, core 쪽 훅 등록").
- **`sales/hooks/record-fields-gate.sh`** — **do not delete**. This file's own
  header comment says it was "adapted per issue-170 from `roles/sales.json`'s
  `produces`, NOT copied from another role's field set" — it is role-owned. Proposal:
  keep this file, but confirm during phase 2 whether core issue #63/#66 exposes a
  shared record-fields gate *engine* that takes a role's required-field list as
  config (analogous to item 4's `RECORD_FIELDS_TERMINAL_STATES` pattern) — if so,
  slim this file down to just the `REQUIRED_FIELDS` list and target-path config,
  sourcing the matching/deny mechanics from core instead of the inline Python here.
  If no such shared engine exists yet, leave this file as-is; it is not covered by
  the issue's "duplicate copy" framing and should not be touched in this batch beyond
  a possible mechanical-only refactor.

**`sales/hooks/hooks.json`** changes: remove the `PreToolUse` → `Bash` entries for
`handbook-trigger-gate.sh` and `trailer-gate.sh` (core's own registration, per issue
background, replaces them). Keep the `SessionStart` → `directive.sh` entry (directive
becomes a stub in item 3, not a removal) and keep the `PreToolUse` → `Write|Edit|...`
entry for `record-fields-gate.sh` (role-owned, stays registered locally unless phase 2
confirms core now owns registration for it too — the issue text does not name
record-fields-gate among the three role-agnostic gates in its background section,
only in its item-2 file list, so this needs explicit confirmation before removal).

## Item 3 — `sales/hooks/directive.sh`

**Proposal**: replace the hand-rolled trap/kill-switch/case scaffolding with a call
into `core/hooks/lib/role-directive.sh`'s `core_role_directive` function, passing this
role's unique fields as arguments/env rather than re-implementing the wrapper logic.
Illustrative target shape:

```bash
#!/usr/bin/env bash
# SessionStart: sales's role directive. Kill switch: export SALES_CYCLE_OFF=1
source "${CLAUDE_PLUGIN_ROOT}/../core/hooks/lib/role-directive.sh"  # exact core path TBD

core_role_directive \
  --role sales \
  --kill-switch-var SALES_CYCLE_OFF \
  --decides "리드/기회를 어떻게 진행시킬지" \
  --use-when "영업 프로세스 설계가 걸릴 때" \
  --produces "sales playbook, stage definitions, qualification criteria" \
  --write-scope "" \
  --hand-off "메시지/포지셔닝 자체는 → marketing" \
  --record "docs/issue-<n>/reports/sales.md, phase-gated per contract v3 s19"
```

The exact calling convention (flags vs. env vars vs. a data file) depends on how
`core_role_directive` is actually implemented — phase 2 must read that function's
real signature from core before finalizing this file, since it is not present in
this working tree and was not independently verified for this proposal. What is
fixed regardless of calling convention: the role-unique payload is exactly the seven
fields already present in the current heredoc (decides / use_when / produces /
write_scope / hand-off / boundary-case wording / record path), and none of the
trap/set/case boilerplate should remain in this file once the shared function owns it.

## Item 4 — Preserve role-level differences via explicit config

The issue gives `RECORD_FIELDS_TERMINAL_STATES` as the worked example for a role that
has a different terminal loop-state set. This repo's seed has no loop-state handling
at all yet, so there is nothing to migrate for that specific config key today.
**Proposal**: treat this item as "keep the pattern available, migrate what exists" —
the one concrete piece of role-local config this repo does have is
`record-fields-gate.sh`'s `REQUIRED_FIELDS` list and its `docs/issue-<n>/reports/sales.md`
target-path suffix. If item 2's phase-2 work finds a shared record-fields engine in
core, that list and path should become this role's equivalent explicit-config
override, following the same shape as `RECORD_FIELDS_TERMINAL_STATES`. If no shared
engine exists, this item is a no-op for this repo until core lands one.

## Item 5 — Confirm `core/hooks/tests/stub-check.sh` passes; record it

No test infrastructure exists in this repo. **Proposal**: phase 2 should, after
making the item 1-3 changes, run core's `stub-check.sh` against this repo (path and
invocation to be confirmed from core, not verified here) and record the pass/fail
result plus the command used in the phase-2 implementation record
(`docs/issue-2/reports/implementation.md`, which is explicitly phase-2-only output
and is therefore not created by this proposal).

## Secondary cleanup implied by items 1-3

- **`README.md`**'s "Layout" section currently describes `warrant-hunter.md`,
  `trailer-gate.sh`, and `handbook-trigger-gate.sh` as files this repo owns/maintains.
  Once items 1-2 land, phase 2 should update those three bullets to say "reference to
  core canon" rather than describing them as if they contain original logic, and drop
  the `trailer-gate.sh` / `handbook-trigger-gate.sh` bullets entirely if those files
  are deleted rather than stubbed.

## Open questions to resolve before/during phase 2 (not blocking this proposal)

1. Exact core repo path/reference syntax for the `warrant/` plugin (item 1) and for
   `core/hooks/lib/role-directive.sh` (item 3) — this repo has no core checkout to
   verify against.
2. Whether `record-fields-gate.sh` is intended to be touched by this batch at all —
   the issue's background section names only three role-agnostic gates
   (trailer/record-fields/handbook-trigger) as landing in `core/hooks/`, which would
   include record-fields-gate, but the survey found its content is role-specific, not
   role-agnostic like the other two. This is a real ambiguity in the issue text worth
   flagging to the issue author before phase 2 touches that file's registration.
3. Whether `core/hooks/tests/stub-check.sh` exists yet in core, and its exact
   invocation, for item 5.
