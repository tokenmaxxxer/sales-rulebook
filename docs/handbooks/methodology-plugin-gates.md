# sales methodology plugin gates and test harnesses

Four self-contained plugins (`sales-proposal-norm/`,
`sales-qualification-meddpicc/`, `sales-stage-definitions/`,
`sales-playbook/`) each carry one PreToolUse gate script under
`hooks/` and one test harness under `tests/run-gate-tests.sh`, per
`docs/issue-10/proposals/methodology-enforcement.md`.

Run any plugin's tests directly, no setup required:

    bash sales-proposal-norm/tests/run-gate-tests.sh
    bash sales-qualification-meddpicc/tests/run-gate-tests.sh
    bash sales-stage-definitions/tests/run-gate-tests.sh
    bash sales-playbook/tests/run-gate-tests.sh

Each harness spins up a disposable git-init repo per case, feeds a
stdin-JSON `Write` (or, for Bash-coverage cases, `Bash`) tool-call payload
to the gate script, and asserts the exit code (`0` = allow, `2` = deny) —
the shape confirmed in `implementation-rulebook/tests/run-gate-tests.sh`
(referenced only, never vendored, per `docs/handbooks/canon-scripts.md`).

Each `hooks.json` `PreToolUse` matcher is `Write|Edit|MultiEdit|Bash`,
matching each gate's own `tool_name` allowlist exactly (issue-16): a
`Bash` command whose extracted write-target token (via
`gate_lib.gate_bash_write_targets`) lands in scope is checked the same as
any other in-scope write, except `gate_reconstruct_write` cannot
content-reconstruct a `Bash` tool_input shape, so an in-scope Bash write
always denies with a "cannot determine the resulting content" message —
the write must go through Write/Edit/MultiEdit to actually be checked.
Each gate's line-2 source statement also carries the mandatory `||`
fail-closed guard (issue-75/issue-16): `. "..." || { echo "<gate>.sh:
cannot source gate-lib.sh" >&2; exit 2; }`, so a misresolved/unreachable
core denies instead of silently running no `gate_*` definitions.

- `proposal-norm-gate.sh` — targets `docs/issue-<n>/proposals/*sales*.md`;
  denies a write missing any of the six phase-1 sections, matched as
  actual markdown headings (not substring). Kill switch
  `SALES_PROPOSAL_NORM_GATE_OFF=1`.
- `qualification-gate.sh` — targets `docs/issue-<n>/reports/sales.md`;
  scopes its check to the section from the `framework_used:` declaring
  line to the next heading of equal-or-higher level. Under
  `framework_used: MEDDPICC`, checks 7 required fields individually (not
  just Economic Buyer/Champion — added per the issue #10 approval comment
  "EB/Champion 외 MEDDPICC 전 필드 검사 추가") plus 2 optional fields
  (present-or-absent, but not label-only if declared), and separately
  requires named Economic Buyer/Champion before advancement past initial
  qualification. Kill switch `SALES_QUALIFICATION_GATE_OFF=1`.
- `stage-definitions-gate.sh` — targets the same record path; requires
  `stage_count` in [5,7] via actual detected stage headings, and
  `>=2` exit criteria plus a named next-stage handoff per stage, scoped
  to that stage's own section body; an optional `Deal state:` label, if
  declared, must be one of a fixed 5-word vocabulary. Kill switch
  `SALES_STAGE_DEFINITIONS_GATE_OFF=1`.
- `playbook-gate.sh` — targets the same record path; requires all five
  playbook sections as actual markdown headings, denies inline
  messaging-script/positioning copy scoped to the sections it appears in.
  Kill switch `SALES_PLAYBOOK_GATE_OFF=1`.

All four source `core/hooks/lib/gate-lib.sh` / `gate-lib.py` (issue-13,
reference-adopting core issue #72's gate-house standard) instead of
hand-rolling their own trap/kill-switch/JSON-parse/path-normalize/
Edit-MultiEdit-reconstruct logic: `gate_trap_fail_closed` at top (before
`set -uo pipefail`), `gate_kill_switch_active` (fail-closed on any
unrecognized kill-switch value), `gate_parse_json_or_deny` (malformed or
non-object JSON denies), `gate_normalize_path`, and
`gate_reconstruct_write` (`replace_all`-aware for both Edit and per-edit
MultiEdit), and `gate_bash_write_targets` (path-shaped-token extraction
from a Bash `command` string, issue-16). `CLAUDE_PROJECT_DIR`/git-root
path resolution and each gate's own methodology-specific semantic check
(section/heading-scoped, label-adjacent, value-capturing — never a
whole-document substring scan) remain each gate's own responsibility,
since gate-lib deliberately does not cover methodology semantics.
`core/hooks/tests/compliance-check.sh` (referenced, never vendored) can
be run against any plugin's `hooks/` directory to confirm gate-lib
adoption, including the `||` source-guard rule. Each plugin's own
`README.md` documents its Install/Layout.

`sales/hooks/tests/name-consistency-check.sh` (issue-16, sales-local, not
core canon) hard-errors on any `sales(-[a-z]+)*`-shaped token in
`README.md` or any plugin's `hooks.json` that isn't a real plugin name
(read out of each `.claude-plugin/plugin.json`'s own `name` field — no
hardcoded list). Wired into `sales/hooks/tests/run-stub-check.sh`
alongside core's `stub-check.sh`; its own synthetic-fixture test lives at
`sales/hooks/tests/run-name-consistency-tests.sh`.

Spec alignment (issue-22): `roles/specs/sales.spec.json` (on-the-record,
MEDDPICC-sourced) is the source of truth for the 9-field MEDDPICC list
(`qualification-gate.sh`'s `verdict` field, added as the 9th, and the
`paper_process`/`competition` optionality split) and the 5-word deal-stage
`loop_state` vocabulary (`stage-definitions-gate.sh`'s optional `Deal
state:` label). Future edits to either field/vocab set should update the
spec file and these two gates together. The spec's `verdict.recomputation`
rule (worst-case-completeness derivation) and `reference_resolution` rule
(named-contact resolution for economic_buyer/champion) are named in each
plugin's README but not enforced here — both are spec-marked
TBD/out-of-scope (issue-521 follow-up) or assigned to an external
`role-spec-reference-guard.sh` hook not present in this repo.

Known open gap (issue-16): `stage-definitions-gate.sh` has no
out-of-scope skip, unlike `qualification-gate.sh`'s `framework_used:`
check or `playbook-gate.sh`'s heading-scoped `mentions_playbook` check —
it requires 5-7 stage headings on *every* write to
`docs/issue-<n>/reports/sales.md`, even when that issue's deliverable
isn't stage-definitions content. A record documenting unrelated work
(e.g. a gate-remediation delivery record) must include a compliant
`## Stage N: <name>` appendix to pass, as this file's own history
demonstrates.
