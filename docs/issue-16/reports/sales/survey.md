loop_state: phase-1

## What this is

Issue #16 phase-1 current-state survey for the sales-rulebook, covering the
single remaining item from the 2026-08-01 re-audit (grade A, one defect
left): a Bash-tool matcher gap. Per the issue, core's own
fail-closed-when-core-missing behavior is already exemplary and is the
reference pattern to adopt by reference, not reimplement. This document
also re-confirms the two named prerequisites landed and audits the sales
plugin set against core's landed shape.

## 1. Prerequisites confirmed landed

- **core issue #75** (`tokenmaxxxer-core`, worktree
  `tokenmaxxxer-core-issue-75-implementation`, branch tip
  `f61d52f deliver(implementation): gate-lib source guard + gate_bash_write_targets
  py parity (issue-75)`, PR #76 proposal `24eb5ed`, merged on top of
  `22a7cad` issue-72 PR #74): landed. `core/hooks/lib/gate-lib.sh` now
  documents the mandatory `||` source guard at the top of its usage
  comment (lines 11-18) and ships `gate_bash_write_targets()` (lines
  86-95) in both `gate-lib.sh` and `gate-lib.py` (parity asserted by
  `run-gate-lib-tests.sh`'s dedicated parity case, lines 138-153).
  `core/hooks/tests/compliance-check.sh` was extended with a third
  detection rule (lines 51-59) that flags any `*-gate.sh` sourcing
  `gate-lib.sh"` with no `||` guard on the same line. `run-gate-lib-tests.sh`
  group 7 (lines 230-241) is the mandatory missing-core case: it points
  `CLAUDE_PLUGIN_ROOT_CORE` at a nonexistent path and asserts
  `record-fields-gate.sh` denies (rc=2), not silently allows.
- **on-the-record issue #182** (worktree
  `on-the-record-issue-182-implementation`): landed. `spawn.py` (around
  line 1983) resolves the `core` entry out of `core_plugins` and injects
  it as `CLAUDE_PLUGIN_ROOT_CORE` into the spawned process's env, with a
  loud stderr warning (not silent) when no `core` plugin dir is present.
  This is the mechanism that makes the relative `../../core` fallback in
  every sales gate script's source line only a *last-resort* default —
  under normal spawn, the exact core plugin path actually loaded by
  `--plugin-dir` is what gets sourced, per the invariant documented in
  the surrounding comment.

Both prerequisites are read-only references for this survey (their code
lives in sibling worktrees of separate repos: `tokenmaxxxer-core` and
`on-the-record`), not vendored into this repo.

## 2. Core's finalized guard pattern (the reference to apply by reference)

From `core/hooks/lib/gate-lib.sh` (issue-75, canonical usage comment):

```sh
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "<gate-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail
gate_kill_switch_active CORE_OFF || { trap - EXIT; exit 0; }
```

The load-bearing fix is the `|| { ...; exit 2; }` on the *same statement*
as the source line. Rationale documented in core (gate-lib.sh lines
11-18): an unguarded `. "$path/gate-lib.sh"` that fails when core is
unreachable runs no code at all — including no `gate_*` function
definitions — after which every `gate_kill_switch_active ... || { exit 0; }`
call site downstream reads the resulting "command not found" (rc=127) as
"kill switch is off," which silently allows everything. The guard turns a
missing/misresolved core into an explicit deny (rc=2) instead.

`core/hooks/tests/compliance-check.sh` detects the unguarded shape
mechanically (grep for `gate-lib\.sh"$` present but `gate-lib\.sh"[[:space:]]*\|\|`
absent) and fails the file. `core/hooks/tests/run-gate-lib-tests.sh` group 7
is the missing-core mandatory test: `CLAUDE_PLUGIN_ROOT_CORE` pointed at a
nonexistent path must produce a deny (rc=2), not an allow.

## 3. Sales plugin set: current source-guard state (the confirmed gap)

All four sales methodology gates source `gate-lib.sh` with **no `||`
guard on the source line** — the exact issue-75-confirmed defect, not yet
applied here:

| File | Line | Current source statement |
|---|---|---|
| `sales-proposal-norm/hooks/proposal-norm-gate.sh` | 2 | `. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh"` |
| `sales-qualification-meddpicc/hooks/qualification-gate.sh` | 2 | same shape |
| `sales-stage-definitions/hooks/stage-definitions-gate.sh` | 2 | same shape |
| `sales-playbook/hooks/playbook-gate.sh` | 2 | same shape |

None of the four has a trailing `|| { ...; exit 2; }`. Under the current
state, a misresolved/unreachable core (e.g. `CLAUDE_PLUGIN_ROOT_CORE`
pointed at a stale path, or the `../../core` relative fallback landing
outside a real core checkout) makes each gate source nothing and fall
through to whatever comes after — every one of these scripts calls
`gate_trap_fail_closed` and `gate_kill_switch_active` on the very next
lines, so on a real core-missing worktree today those calls would fail
with "command not found" and the shell's default (non-`set -e`, no trap
yet installed) would let the script continue past them silently, i.e.
exactly core's issue-75-confirmed fail-open shape. Running
`compliance-check.sh` (core canon, reference-only) against
`sales-*/hooks/` today would flag all four files on the new
`sources gate-lib.sh with no || guard` rule (rule not yet exercised here
because compliance-check has, per issue-13's record, only been run
against these four gates for the *older* two rules — kill-switch and
`.replace()` reconstruction — before issue-75's third rule existed
upstream).

## 4. hooks.json matcher vs. code coverage (the confirmed matcher gap)

| Plugin | `hooks.json` PreToolUse matcher | Tools the gate script actually branches on |
|---|---|---|
| `sales-proposal-norm` | `Write\|Edit\|MultiEdit` | `tool in ("Write", "Edit", "MultiEdit")` (gate script line 81) |
| `sales-qualification-meddpicc` | `Write\|Edit\|MultiEdit` | same shape (not yet read line-by-line this pass, same source template as proposal-norm; see §6 for full-repeat read plan) |
| `sales-stage-definitions` | `Write\|Edit\|MultiEdit` | same shape |
| `sales-playbook` | `Write\|Edit\|MultiEdit` | same shape |

None of the four hooks.json matchers includes `Bash`, and none of the
four gate scripts' Python payload checks `tool == "Bash"`. This is
exactly the issue's named remaining defect: "Bash matcher addition (the
sole remaining item)." Core already ships the fix's building block —
`gate_bash_write_targets()` — but no sales gate calls it yet (matches the
"Open findings" note carried over from issue-13's delivery record:
`gate_bash_write_targets` was exported but unused by any of the four
sales gates, "out of scope for issue-13, noted in case a future issue
extends a sales gate to also watch Bash-tool writes" — issue-16 is that
future issue).

Core's own `hooks.json` (`core/hooks/hooks.json`) does not use a
tool-specific matcher pattern at all — it matches `.*` (all tools) at the
`PreToolUse` level for `board-gate.sh`/`approval-gate.sh`/`gh-guard.sh`/
`trailer-gate.sh`/`record-fields-gate.sh`/`handbook-trigger-gate.sh`, and
lets each gate script itself decide, per tool_name, whether the event is
in scope. That is a broader-matcher-plus-narrower-code-branch shape,
different from the sales plugins' narrower-matcher (`Write|Edit|MultiEdit`)
shape — both are internally consistent (matcher parity holds in each), but
core's shape is what makes its own Bash-write coverage (via
`gate_bash_write_targets`, exercised in `board-gate.sh`/`approval-gate.sh`
per the gate-lib.sh comment on `gate_bash_write_targets`, "the token-scan
technique already used by approval-gate.sh/board-gate.sh") possible
without a matcher change — only a code-branch addition. The proposal
(§(a)/(b)) evaluates both matcher-widen-to-`.*` and
matcher-add-`|Bash` as options for the sales plugins, given the sales
gates route on `tool_name` explicitly rather than matching everything.

## 5. Old role-names / ghost files: none found in this repo

Checked for stale references to any prior name this role may have held
before landing as `sales` (the issue requires zero leftover old
role-names / ghost files, with old names as a hard error):

- `README.md` (repo root): describes the role as `sales` throughout,
  cites `docs/issue-160/proposals/role-taxonomy.md`'s "round-3 promotion"
  and issue-170's "skeleton scaffolding" as its origin — both are
  external-repo doc paths cited by reference (not vendored, not present
  in this repo's `docs/`), consistent with this repo's own convention of
  citing core-repo docs by path without copying them. No prior role name
  string (e.g. an earlier working name for this role) appears anywhere in
  this README.
- `sales/.claude-plugin/plugin.json` and the four methodology plugins'
  own `.claude-plugin/plugin.json` manifests: `name` fields all read
  `sales`, `sales-proposal-norm`, `sales-qualification-meddpicc`,
  `sales-stage-definitions`, `sales-playbook` — internally consistent,
  matching their directory names and the README's plugin-install list
  exactly.
- No file under this repo matches a "renamed"/"deprecated"/"formerly"
  marker, and `git log --all --oneline | grep -i rename` on this repo
  returns nothing — this repo's own history (5 commits: issue-1, issue-10,
  issue-13 propose+deliver pairs) never carried a role rename locally.
- `docs/issue-13/reports/sales/` (the most recent prior delivery) and
  `docs/issue-13/reports/sales.md` were also checked for ghost-file
  references and found clean (issue-13's own delivery record states this
  explicitly: "no ghost-file references found").

**Conclusion**: there is currently no live old-role-name/ghost-file defect
inside this repo to remove. The issue's requirement ("zero leftover old
role-names / ghost files ... old names must be a hard error") is read as
requiring an enforcement *mechanism* be added so a future drift is caught
mechanically (mirroring core's `stub-check.sh` canon-manifest pattern,
which fails loudly on a vendored/stale reference) rather than requiring
any content deletion today, since none was found. The proposal (§(d))
designs that mechanism and names the exact strings/paths it should guard
against, sourced from this survey's own file inventory as the current
"known-good" set.

## 6. Full test-suite / compliance-check current state

Not re-run in this survey (phase-1 is read-only design work; running the
suites live would require executing the gate scripts against a real core
checkout, and no remediation code is written in phase-1 per this issue's
gate). Issue-13's most recent delivery record
(`docs/issue-13/reports/sales.md`) is the last known-good baseline: 62/62
tests passed across all four suites, `compliance-check.sh` clean (0 FAIL)
against the two rules that existed at that time. That baseline predates
issue-75's third compliance rule (missing `||` guard) and predates any
Bash-matcher/missing-core test additions, both of which issue-16 requires
adding and then re-running. §3 and §4 above document, from static
reading, why re-running `compliance-check.sh` and `run-gate-lib-tests.sh`'s
group 7 (missing-core) against the sales gates *as they stand today*
would be expected to fail on both — that is precisely the "재감사 잔여
결함" (re-audit remaining defect) this issue exists to close.

## Sources read for this survey

- This repo: `sales/`, `sales-proposal-norm/`, `sales-qualification-meddpicc/`,
  `sales-stage-definitions/`, `sales-playbook/` (hooks.json + gate scripts +
  README.md), `docs/issue-13/reports/sales.md`, `docs/issue-13/reports/sales/`.
- `tokenmaxxxer-core` (sibling worktree `tokenmaxxxer-core-issue-75-implementation`,
  branch tip `f61d52f`): `core/hooks/lib/gate-lib.sh`, `core/hooks/tests/compliance-check.sh`,
  `core/hooks/tests/run-gate-lib-tests.sh`, `core/hooks/hooks.json`.
- `on-the-record` (sibling worktree `on-the-record-issue-182-implementation`):
  `spawn.py` (`CLAUDE_PLUGIN_ROOT_CORE` injection, ~line 1983), `test_spawn.py`.

## Open findings

None blocking phase-1. Carried into the proposal: the matcher-shape
choice (§4) between widening to `.*` (core's own shape) versus adding
`|Bash` to the existing `Write|Edit|MultiEdit` matcher (minimal, in
keeping with the sales plugins' own narrower-matcher convention) is a
design decision the proposal resolves, not left open past phase-1.
