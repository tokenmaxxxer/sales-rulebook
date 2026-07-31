---
subject: issue-10
role: sales
---

# Scout brief

Mode: batched-sequential (single session, no parallel subagent dispatch —
this pass reads local sibling checkouts, not the web). Stages used: 1
(sweep only; judge point 1 found no mismatch worth a deepening round —
saturates immediately, see below).

Field surveyed: not an external product/business genre. Issue-1's own
adoption rationale already established that this repo's comparables are
*other rulebook plugins in this same monorepo family*, not an
externally-sourced genre — issue-10 explicitly names one of them
(`implementation-rulebook`) as the target bar. The sweep angle is
therefore: read the sibling rulebooks that already built this exact
mechanism (methodology gate, directive depth, gate tests) and extract
their must-bes, rather than web-searching for generic "policy-as-code"
exemplars that would not share this repo's hook/contract substrate.

## Sweep (3 angles, one round)

- **By-gate-shape** — `pricing-rulebook/pricing/hooks/methodology-gate.sh`:
  a PreToolUse gate targeting proposal *and* record write surfaces (not
  just the record), fail-closed trap-at-top (`__fc` remap of any non-0/2
  exit to 2), path resolution via `CLAUDE_PROJECT_DIR` with a git-root
  fallback, and a checklist of required elements checked by keyword/regex
  presence with an explicit "missing" list assembled before a single
  `deny()` call.
- **By-order-enforcement** —
  `implementation-rulebook/coding/hooks/coding-progress-gate.sh`: the one
  example of a sequencing rule enforced mechanically (a commit is refused
  while an unresolved `severity: blocking` finding addressed to the role
  exists, until the record shows a `resolved_findings` entry AND the
  finder's own `loop_state` reads `cleared`). This is the pattern for
  "must not advance past X until Y" state tracking, done via record-field
  state rather than a separate state file.
- **By-test-shape** — `implementation-rulebook/tests/run-gate-tests.sh`:
  synthesizes a throwaway git repo per case, pipes a JSON tool-call payload
  into the gate script over stdin, and asserts on the exit code
  (0=allow, 2=deny, else exit-N) — no mocking of the gate itself, real
  subprocess invocation.

## Judge point 1 (saturation)

All three angles converge on one underlying pattern (fail-closed
PreToolUse gate + real-subprocess test harness); no disagreement across
angles, no angle turned up a competing shape. A second round would not
change which pattern to adopt — stopping at stage 1.

## Must-bes (Kano) extracted

- Fail-closed trap-at-top (`trap __fc EXIT`) on every gate script — a gate
  that fails open on an internal error is worse than no gate.
- Gate targets the exact write-surface path(s) by regex against a
  resolved, git-root-relative path — never a bare substring match on the
  raw `file_path` string (path traversal / symlink risk).
- Reconstruct *resulting* content for Write/Edit/MultiEdit the same way
  before checking for required elements — checking `tool_input` fields
  directly would miss content delivered via Edit's `new_string` splice.
- One `missing = [...]` list assembled across all checks, one final
  `deny()` naming all of them — never fail on the first missing element
  and hide the rest.
- Sequencing/order rules are enforced via record-field state
  (`resolved_findings` + `loop_state: cleared`), not a bespoke state file —
  matches this repo's existing `RECORD_FIELDS_TERMINAL_STATES` idiom
  (referenced in `sales/hooks/record-fields-gate.sh`'s own header comment).
- Gate tests spin up a disposable git repo per case and invoke the real
  script via stdin JSON; assert exit code only (0/2/other).

## Performance axes (where exemplars differ, and which to pick)

- Keyword-presence vs. structural parse: pricing's gate is keyword/regex
  presence only (no markdown structure parsing) and that has been
  sufficient there — adopt the same for sales rather than building a
  markdown-section parser, since the effort is disproportionate to the
  gain (a keyword check is already stronger than sales's current
  single-field check and matches this repo's existing tooling level).
- New gate file vs. extending the existing one: pricing kept a single
  `methodology-gate.sh` separate from core's generic record-fields gate,
  covering *both* the proposal and record surfaces itself. Sales currently
  has its methodology check folded inside a file literally named
  `record-fields-gate.sh`, which undersells its own scope and doesn't
  cover proposals at all — adopt pricing's shape: a distinctly-named
  `methodology-gate.sh` covering both surfaces.

## Adopt / skip

- **Adopt**: fail-closed trap, resolved-path regex matching, full-content
  reconstruction, single missing-list deny, record-state sequencing,
  disposable-repo gate tests.
- **Skip**: a bespoke agent/checklist file — methodology-norms.md names no
  repeated multi-step procedure beyond the deliverable-shape checks the
  gate itself already encodes, and none of the three surveyed sibling
  rulebooks add a role-specific agent for their methodology gate either
  (only core's cross-cutting `warrant` hunt agent, already referenced).

## Segment fit

Sales's methodology (MEDDPICC/BANT + stage definitions + playbook) is
richer in required-field count than pricing's (six elements) but shares
the same shape: a fixed component checklist per deliverable kind, one
explicit sequencing rule. `implementation-rulebook`'s coding gate is the
closer bar for the sequencing half specifically (Economic
Buyer/Champion-before-advance mirrors coding's
blocking-finding-before-commit shape) even though its subject matter
(verify findings) differs.

## Gap line

Already met by current state: keyword-presence gating exists (if thin);
phase split exists in prose (methodology-norms.md, not the directive).
Missing entirely: phase-1 proposal write-surface gate; per-stage
component checks beyond field-name presence (exit-criteria count,
past-tense naming); the Economic Buyer/Champion sequencing rule has zero
mechanical enforcement; no gate tests at all; directive text carries no
phase split or facet-level criteria.

Sources: /home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/methodology-gate.sh; /home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/coding-progress-gate.sh; /home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/tests/run-gate-tests.sh; /home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/directive.sh (read for directive-depth precedent); docs/issue-1/proposals/methodology-norms.md (this repo's own adopted norms, the enforcement target).
