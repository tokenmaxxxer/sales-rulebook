loop_state: phase-1

## Scout brief — issue #16 gate A+ remediation (Bash matcher + guard parity)

**External web search**: not used. This task is scoped entirely to
adopting an already-landed, explicitly-named internal reference (core
issue #75's finalized gate-lib pattern), which the issue names as the
authority to apply "by reference" rather than re-derive — an internal
comparison against that landed pattern is the primary and sufficient
exemplar here. One general-knowledge check (no live search) on Claude
Code `hooks.json` matcher syntax is included below since it's a
convention question, not a design-taste question.

**Must-bes** (non-negotiable, from the issue + core's landed pattern):
- Source-guard the `.` line with `|| { ...; exit 2; }` on the same
  statement — core's issue-75 fix, exact syntax mandatory (a bare
  guard elsewhere doesn't close the "no code ran, including no gate_*
  defs" gap).
- `compliance-check.sh` (core canon, referenced not vendored) must pass
  clean (0 FAIL) against all four sales gates after the change.
- A missing-core mandatory test case per gate suite, mirroring core's
  `run-gate-lib-tests.sh` group 7 shape exactly (point
  `CLAUDE_PLUGIN_ROOT_CORE` at a nonexistent path, assert deny/rc=2).
- hooks.json matcher must have 1:1 parity with what the gate code
  actually branches on — no matcher wider or narrower than the code's
  own `tool_name` checks.
- Old role-names must be a *hard error*, not a warning or silent skip.

**Chosen axes** (what this scout pass evaluates, given the must-bes
above are fixed): (1) matcher shape — widen to `.*` (core's own
convention) vs. add `|Bash` to the existing narrow matcher; (2) how a
Bash-tool write should be scoped to "does this line up with the same
write-target check Write/Edit/MultiEdit already run" vs. a weaker
presence-only check.

**Adopt**: add `|Bash` to each of the four `hooks.json` matchers
(`Write|Edit|MultiEdit|Bash`) rather than widening to `.*`. Reasoning:
the sales gates, unlike core's own `.*`-matched gates, already hard-code
`tool_name in (...)` as their in-scope check inside the Python payload —
switching the matcher to `.*` without also loosening that in-code check
would be dead weight (the gate would still no-op on every other tool),
and loosening the in-code check to accept everything would be broader
than the issue asks for (the issue specifically names "Bash matcher
addition," singular). Adding exactly one tool to the matcher, paired
with exactly one new `tool == "Bash"` branch that calls
`gate_bash_write_targets()` and re-runs the *same* target-path regex
(`docs/issue-<n>/proposals/*sales*.md`-shaped, one pattern per plugin)
against each returned token, keeps matcher-to-code parity exact and
mirrors core's own justification for `gate_bash_write_targets`
("the token-scan technique already used by approval-gate.sh/board-gate.sh").

**Skip**: matching `.*` at the hooks.json level (core's shape) — correct
for core because core's gates already self-scope per-tool_name broadly
across six different gates in one file; wrong fit here because it would
require also touching the in-code tool_name allowlist in all four
gates, which is strictly more change than the issue's single named
defect calls for. Also skip: a generic Bash-command-string substring
scan independent of `gate_bash_write_targets` — core built the shared
token-extraction helper precisely so downstream gates don't hand-roll
this, and hand-rolling it here would reproduce the exact
re-implementation problem issue-13's delivery record already flagged as
out of scope to avoid.

**Gap line**: the sales plugin set has adopted core's gate-lib for
kill-switch/JSON-parse/path-normalize/reconstruct (issue-13, landed) but
has not yet adopted the two building blocks core added afterward
(issue-75): the mandatory `||` source guard, and
`gate_bash_write_targets`-based Bash coverage. Both are drop-in calls
against an already-shipped, already-tested core function — no new
algorithm design needed on the sales side, only wiring plus the four
per-plugin missing-core/Bash-coverage test cases.

**Sources**:
- `core/hooks/lib/gate-lib.sh` (issue-75, `tokenmaxxxer-core` sibling
  worktree `tokenmaxxxer-core-issue-75-implementation`, tip `f61d52f`) —
  primary internal exemplar, read directly (not guessed).
- `core/hooks/tests/compliance-check.sh` and
  `core/hooks/tests/run-gate-lib-tests.sh` (same worktree) — the
  detection rule and the mandatory missing-core test shape.
- `core/hooks/hooks.json` (same worktree) — the contrasting `.*`-matcher
  convention, read to justify the "skip: widen to `.*`" call above
  rather than assumed.
- `on-the-record/spawn.py` (sibling worktree
  `on-the-record-issue-182-implementation`) — `CLAUDE_PLUGIN_ROOT_CORE`
  injection, confirming the guard's fallback path is a last resort, not
  the normal-path resolution.
- `docs/issue-13/reports/sales.md` (this repo) — prior delivery baseline
  and the explicit open finding ("`gate_bash_write_targets` ... unused by
  any of the four sales gates ... out of scope for issue-13") this issue
  closes.
- General knowledge (no live search performed): Claude Code `hooks.json`
  `PreToolUse` matcher is a regex tested against `tool_name`; alternation
  via `|` is the standard multi-tool-match idiom, consistent with what
  both core's and the sales plugins' own existing `hooks.json` files
  already do.
