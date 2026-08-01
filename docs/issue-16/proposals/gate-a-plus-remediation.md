Status: PROPOSED (phase-1, awaiting approval)

## Scope

Issue #16, "게이트 A+ 최종 마감: 재감사 잔여 결함 보수 (재감사 등급 A)":
close the single remaining 2026-08-01 re-audit defect against the sales
plugin set (`sales-proposal-norm`, `sales-qualification-meddpicc`,
`sales-stage-definitions`, `sales-playbook`) — a Bash-tool matcher gap —
plus, per the issue's four numbered requirements, the shared-item fixes
that ride along with it by reference to core issue #75's already-landed
pattern: the mandatory source guard, matcher/code parity, the
missing-core mandatory test, and a hard-error check against stale old
role-names/ghost files. This document is the design; no gate script,
`hooks.json`, or README is edited by this PR — see `docs/issue-16/reports/sales/survey.md`
for the current-state evidence this design is built against.

## Guiding principle

Adopt core's finalized pattern by reference, exactly as issue-13's prior
delivery did for core issue #72: call the shared `gate_*` functions
core already ships (issue-75: the `||` source guard shape,
`gate_bash_write_targets`), never re-derive or hand-roll an equivalent.
The issue's precondition explicitly names this ("core's ... behavior is
already exemplary" — i.e. don't reinvent it, consume it).

## Per-item breakdown

### (a) New Bash matcher + which rule it enforces

Add `Bash` to each of the four plugins' `hooks.json` `PreToolUse`
matcher, changing `"matcher": "Write|Edit|MultiEdit"` to
`"matcher": "Write|Edit|MultiEdit|Bash"` in:

- `sales-proposal-norm/hooks/hooks.json`
- `sales-qualification-meddpicc/hooks/hooks.json`
- `sales-stage-definitions/hooks/hooks.json`
- `sales-playbook/hooks/hooks.json`

Paired code change (each gate script's Python payload, one new branch
per gate): where the script currently does
`if tool not in ("Write", "Edit", "MultiEdit"): sys.exit(0)`, extend to
also accept `"Bash"`, then when `tool == "Bash"`, call
`gate_lib.gate_bash_write_targets(ti.get("command", ""))` (the sh
version is available too; the Python payload already loads
`gate_lib` via `GATE_LIB_PY`, so calling the Python function keeps one
call site) and apply the *same* per-plugin target-path regex
(e.g. proposal-norm's `^docs/issue-[0-9]+/proposals/.*sales.*\.md$`)
against each returned token instead of against a single `file_path`.
If any token matches, the write is in scope and the existing
section/heading semantic check runs against the resulting file content
exactly as it does today for Write/Edit/MultiEdit — this reuses the
gate's own current-content-read + section-check code unchanged, only
the "is this write in scope, and what file does it target" front end
gains a second, Bash-shaped path. If no token matches, `sys.exit(0)`
(out of scope), same as today's non-matching Write/Edit/MultiEdit case.

This is the write-target/source-guard rule core #75 built
`gate_bash_write_targets` to let a Write/Edit/MultiEdit-only gate also
enforce against a Bash-based file write (e.g. `cat > docs/.../proposal.md`
or `python3 - <<'PY' ... open(...).write(...)`-shaped commands whose
resulting write target is extractable as a path-shaped token from the
command string) — the exact case issue-13's delivery record flagged as
the deferred, then-out-of-scope, open finding.

### (b) Full matcher-to-code coverage table

| Plugin | `hooks.json` matcher (after fix) | Code tool_name allowlist (after fix) | Parity |
|---|---|---|---|
| `sales-proposal-norm` | `Write\|Edit\|MultiEdit\|Bash` | `("Write","Edit","MultiEdit","Bash")` | exact |
| `sales-qualification-meddpicc` | `Write\|Edit\|MultiEdit\|Bash` | `("Write","Edit","MultiEdit","Bash")` | exact |
| `sales-stage-definitions` | `Write\|Edit\|MultiEdit\|Bash` | `("Write","Edit","MultiEdit","Bash")` | exact |
| `sales-playbook` | `Write\|Edit\|MultiEdit\|Bash` | `("Write","Edit","MultiEdit","Bash")` | exact |
| `sales` (role-shell) | none (SessionStart only, no `PreToolUse`) | n/a | exact (no PreToolUse gate lives in `sales/hooks/hooks.json` today; unchanged) |

No mismatch survives the fix in either direction: every matcher entry
has a corresponding code branch, and no code branch checks a tool_name
absent from its own matcher. This table is the acceptance check for
issue requirement 2 ("full parity between hooks.json matchers and the
tool coverage implemented in code") — phase 2 re-verifies it by reading
both files side by side per plugin, the same method used to build this
table.

### (c) Missing-core fail-closed test case design

For each of the four plugins' `tests/run-gate-tests.sh`, add one case
mirroring core's `run-gate-lib-tests.sh` group 7 exactly:

```sh
# missing-core: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere must deny, not allow
td="$(mktemp -d)"
out="$(printf '{"tool_name":"Write","tool_input":{"file_path":"docs/issue-1/proposals/x-sales.md","content":"x"}}' \
    | env CLAUDE_ROLE=sales CLAUDE_PROJECT_DIR="$td" \
      CLAUDE_PLUGIN_ROOT_CORE="$td/no-such-core" \
      /bin/bash "$HOOKS/proposal-norm-gate.sh" 2>&1)"
rc=$?
got=$([ $rc = 0 ] && echo allow || { [ $rc = 2 ] && echo deny || echo "exit-$rc"; })
report deny "$got" \
  "proposal-norm-gate.sh: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere denies (not silent-allow)"
rm -rf "$td"
```

(one instance per plugin, gate script name and a representative in-scope
`file_path`/target substituted). This is the direct behavioral proof
that (a)'s prerequisite — the `||` source guard added to each gate's
line-2 source statement, per core #75's exact syntax
(`. "..." || { echo "<gate-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }`)
— actually closes the fail-open gap documented in the survey §3, rather
than merely looking closed. This test must be added to all four
`tests/run-gate-tests.sh` files (currently at 16/14/17/15 passing cases
per issue-13's baseline; each grows by exactly one mandatory case, plus
a Bash-coverage case per (a)/(b) above — two new cases per suite, four
suites, mirroring the two new groups core's own harness added, `Bash`
coverage and `missing-core`).

### (d) Old role-names / ghost files: hard-error mechanism

The survey (§5) found no live old-role-name or ghost-file reference
inside this repo today — `README.md`, all five `.claude-plugin/plugin.json`
manifests, and the four gate scripts all consistently use `sales`,
`sales-proposal-norm`, `sales-qualification-meddpicc`,
`sales-stage-definitions`, `sales-playbook`. Since the issue requires
this be a *hard error*, not merely "currently clean," the design adds a
mechanical check rather than relying on a point-in-time audit staying
true:

- New script `sales/hooks/tests/name-consistency-check.sh` (referenced
  the same way `sales/hooks/tests/run-stub-check.sh` already references
  core's `stub-check.sh` — a thin wrapper, not a vendored copy of core
  logic, since this specific check is sales-local, not core canon).
- Mechanism: read `name` out of each of the five `.claude-plugin/plugin.json`
  files, build the "known-good" set from that (self-describing — no
  hardcoded name list to drift), then grep `README.md` and all five
  `hooks.json` files for any plugin-name-shaped token
  (`sales(-[a-z-]+)?`) that is *not* in the known-good set. Any hit is a
  hard error (non-zero exit, printed reason: file + offending token),
  mirroring `stub-check.sh`'s own "found something that shouldn't be
  there, refuse" shape rather than a soft warning.
- Because no old name currently exists to seed a regression fixture
  against, the test suite for this check instead exercises it
  synthetically (same technique core's own
  `run-gate-lib-tests.sh` uses for `compliance-check.sh`, §"synthetic
  hand-rolled violation" case, lines 204-215 of that file): write a
  fixture README/manifest pair containing a deliberately stale name
  (e.g. `sales-outreach-cadence`, a plausible-but-nonexistent 5th
  methodology plugin name) into a tempdir and assert the check exits
  non-zero against it, then assert it exits zero against this repo's
  real `README.md`/manifests as they stand today.
- Wired into `sales/hooks/tests/run-stub-check.sh` as an additional
  invocation (not folded into stub-check.sh itself, since drift-recurrence
  detection there is core canon scope and this is a sales-local
  self-naming check), so a future CI/test run surfaces a hard failure
  the moment any file introduces a stale plugin-name string — matching
  the issue's "old names must be a hard error" wording exactly.

### (e) CLAUDE_PLUGIN_ROOT_CORE (on-the-record #182) consumption

No sales-side code change is required to *consume* #182 — `spawn.py`
(the on-the-record repo) is the injector, and every sales gate's source
line already reads `${CLAUDE_PLUGIN_ROOT_CORE:-<relative fallback>}` as
its first-choice value (survey §3 table). What (a)'s `||`-guard fix
changes is what happens when that consumption *fails* — today, a
misresolved value (env var unset because #182's injection didn't run,
e.g. an un-spawned/manually-invoked gate, or a spawn path that predates
#182) falls through silently past `gate_trap_fail_closed`; after the
fix, the same case is an explicit deny. The design therefore treats
#182 as the *normal-path* resolution (the injected value should always
point at the real loaded core plugin per the invariant `spawn.py`'s own
comment documents) and (a)'s guard as the *fail-closed backstop* for
every other path — manual invocation, a stale spawn wrapper, a
misconfigured `--plugin-dir` — consistent with core's own gate-lib.sh
usage comment treating the guard as unconditional, not conditioned on
whether #182-style injection is present.

## Adoption rationale

All four fixes are drop-in calls against code core has already written,
tested, and landed (issue-75) or already runs correctly (spawn.py
issue-182) — there is no new algorithm to design on the sales side, only
wiring plus per-plugin test cases in the exact shape core's own harness
already proves out. This keeps the sales plugin set's methodology-check
logic (the actual differentiator: MEDDPICC/BANT fields, stage exit
criteria, playbook sections, proposal-norm sections) completely
untouched — only the front-end "is this write in scope, and did core
load successfully" plumbing changes, matching the same minimal-footprint
shape issue-13's core-adoption delivery used for gate-lib's first three
functions.

## Plugin-reflection plan

Once approved and delivered (phase 2), this closes the sole outstanding
2026-08-01 re-audit defect and should move the sales plugin set's grade
from A to the issue's target A+. No new plugin or methodology is
introduced; all four existing methodology plugins are touched
identically (source-guard line + one Bash branch + hooks.json matcher +
two new test cases each), plus the new sales-local
`name-consistency-check.sh` under the `sales/` role-shell plugin (its
`hooks/tests/` directory, alongside the existing `run-stub-check.sh`
wrapper). No plugin is added, removed, or renamed by this design.

## Phase 1 only

This PR is the survey + this proposal only. No gate script, `hooks.json`,
README, or test file is modified. No `APPROVE` comment is posted by this
delivery, and no merge is performed by this delivery. Phase 2 (the
actual remediation: editing the four `hooks.json` files, the four gate
scripts, the four `tests/run-gate-tests.sh` files, and adding
`sales/hooks/tests/name-consistency-check.sh`) is gated on human approval
of this proposal and is explicitly out of scope for this PR.
