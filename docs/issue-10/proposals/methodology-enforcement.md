# Issue #10 — Proposal: Enforcement Layer for the Adopted Sales Methodology Norms

Status: **proposal only, phase 1**. No directive text, gate script, or test
is edited by this document or by this phase. Execution is phase 2, gated on
human Approve per contract v3 s19. Scoped against
`docs/issue-10/reports/sales/current-state-survey.md` and
`docs/issue-10/reports/sales/scout-brief.md`.

## Scope

Builds the mechanical enforcement layer for the norms already adopted in
`docs/issue-1/proposals/methodology-norms.md` (a)/(b)/(d) — that document is
the norm source; this proposal is only about turning it into hook machinery,
per issue-10's four asks and the implementation-rulebook quality bar it
names. No new methodology content is introduced here.

## Guiding principle

Every enforcement mechanism proposed below exists to close one specific gap
the survey found between "the norm is written down" and "a write that
violates the norm is mechanically refused" — never to add a check for its
own sake. Where the scout pass found a converged, working shape in sibling
rulebooks (fail-closed trap-at-top, resolved-path regex matching, a single
missing-list `deny()`, record-state sequencing, disposable-repo gate tests),
this proposal adopts that shape verbatim rather than inventing a new one;
where sales's methodology has no analogue to a surveyed pattern (a
repeated multi-step procedure needing a checklist/agent), this proposal
declines to add one rather than manufacture a use for it.

## Per-item breakdown

### 1. Directive depth (`sales/hooks/directive.sh`)

**What changes**: expand the current single-line `PRODUCES` string (and add
phase-aware structure to `YOU_DECIDE`/`USE_WHEN`/`HAND_OFF`) into multi-line
directives that state, per facet, the judgment criteria and prohibitions —
matching the depth of `implementation-rulebook/coding/hooks/directive.sh`'s
four variables (verified: that file's `PRODUCES` alone runs to 12 lines of
named rules, not a one-line noun phrase).

**Why**: tied to the guiding principle — a directive that only names the
deliverable ("stage definitions, entry/exit criteria") gives the model
nothing to check its own draft against before a human or gate does; a
directive that states the judgment criteria ("exit criteria must be past-
tense completed buyer actions, never rep-judgment/activity verbs") lets the
model self-correct before the write even reaches the gate.

**Illustrative target shape** (non-final, phase-2 wording TBD):

- `YOU_DECIDE`: unchanged decision statement, plus one line naming that
  progression judgment is falsifiable-state-based, never mood-based (ties
  to methodology-norms.md (c)'s "not a mood" rationale).
- `USE_WHEN` (phase 1, research/current-state-survey/proposal facets): what
  the phase-1 field is for this role (methodology precedent = sibling
  in-repo rulebooks first, external sales-methodology sources second, per
  methodology-norms.md (a)); the six required proposal sections in order;
  the evidence-format rule (source URL or file path, else labeled
  assumption).
- `PRODUCES` (phase 2, per-deliverable facets): one paragraph each for
  qualification criteria, stage definitions, and sales playbook, each
  stating: the required components, the explicit prohibition (no silent
  framework-field omission; no rep-judgment exit criteria; no messaging/
  positioning content — hand off to `marketing` instead), and which gate
  gets applied to that deliverable.
- `HAND_OFF`: record requirement — `docs/issue-<n>/reports/sales.md` is the
  only phase-2 record home, written as first act of phase 2, per the
  contract's record-discipline norm coding's directive already states
  (adopt the same "measured: a phase-1-only issue left the record empty"
  framing, restated for this role).

### 2. Methodology gate

**What changes**: replace `sales/hooks/record-fields-gate.sh` with a
distinctly-named `sales/hooks/methodology-gate.sh`, covering **both** write
surfaces (per scout finding — pricing's gate covers proposal and record
together; sales's current gate only covers the record and undersells its
own scope by living inside a file literally named `record-fields-gate.sh`).

**Why**: the survey found phase-1 proposals have zero mechanical check
today, and the phase-2 record check is keyword-presence-only for three
field names, missing most of methodology-norms.md (b)'s actual required
components. The scout pass's adopt list (fail-closed trap, resolved-path
regex, full-content reconstruction, single missing-list deny) is the
directly-reusable shape; this item is mechanical application of that shape,
not a new design.

**Illustrative target shape** (non-final — exact regex/keyword list is
phase-2 detail):

- Fail-closed trap-at-top (`trap __fc EXIT`), matching
  `pricing/hooks/methodology-gate.sh` line 2-3 and
  `implementation-rulebook/coding/hooks/coding-progress-gate.sh` line 2-9.
- Path targets: `docs/issue-[0-9]+/proposals/.*sales.*\.md` (phase-1) and
  `docs/issue-[0-9]+/reports/sales\.md` (phase-2), resolved against
  `CLAUDE_PROJECT_DIR` with a git-root fallback exactly as pricing's gate
  does (verified pattern, not reinvented).
- Phase-1 proposal check: the six required sections from
  methodology-norms.md (a) — status banner, scope line, guiding principle,
  per-item breakdown, adoption rationale, plugin-reflection plan — checked
  by heading/keyword presence (e.g. a case-insensitive section-heading scan
  for "status", "scope", "guiding principle", "adoption rationale",
  "plugin-reflection"), assembled into one missing-list `deny()`.
- Phase-2 record check, extending today's three conditions:
  - qualification criteria: `framework_used` present **with a MEDDPICC or
    BANT value**, not just the bare key (today's gate accepts an empty/
    placeholder key — confirmed gap in the survey); when the record states
    an opportunity has advanced past initial qualification (heuristic:
    stage name matching a past-initial-qualification stage list, or an
    explicit "advanced" / "past qualification" phrase), `economic_buyer`
    and `champion` must both be present with non-TBD values — this is the
    proposal's sequencing rule, and unlike coding's cross-record check it
    resolves within a single document (the record states both the stage
    and the field in the same write), so no cross-file state file is
    needed.
  - stage definitions: `stage_count` present as an integer in the surveyed
    5-7 range; `exit_criteria_present` per stage; a lightweight past-tense
    heuristic (deny if a stage-name line matches a known rep-activity verb
    list such as "had", "did", "presented", "called" with no completed-
    action phrasing) — flagged as heuristic, not a full NLP parse, matching
    the scout finding that keyword/regex presence (not structural markdown
    parsing) is this repo family's accepted precision level.
  - playbook: all five required sections present by heading keyword (process
    overview, qualification framework, ICP/persona, objection-handling,
    metrics), and a deny when messaging-script/positioning-copy content is
    detected inline rather than referenced (out-of-scope check, ties to the
    hand-off boundary).
- Kill switch: `SALES_METHODOLOGY_GATE_OFF=1`, matching the existing
  convention (`SALES_RECORD_FIELDS_GATE_OFF`, `PRICING_METHODOLOGY_GATE_OFF`).

**Sequencing note**: methodology-norms.md names exactly one order
constraint (Economic Buyer/Champion before stage advancement), and it is
checkable within a single record write — no `loop_state`/cross-file state
tracking (coding's `resolved_findings` + `loop_state: cleared` pattern) is
needed for this role's norms as adopted. If a future issue introduces a
genuinely cross-document sequencing rule (e.g. a stage-advancement record
that must reference a separately-dated qualification record), that would
warrant the coding-gate's cross-record shape at that time — out of scope
here since no such rule exists in the adopted norms.

### 3. Gate tests

**What changes**: add `tests/run-gate-tests.sh` at repo root (currently
absent), following
`implementation-rulebook/tests/run-gate-tests.sh`'s shape: synthesize a
disposable git repo per case, pipe a JSON tool-call payload over stdin into
the real gate script, assert on exit code (0=allow, 2=deny, other=labeled).

**Why**: issue-10 requires pass/fail cases at repo root; the survey found
none exist, and `sales/hooks/tests/run-stub-check.sh` only wraps core's
generic drift check, which does not exercise gate logic at all.

**Illustrative target shape** (non-final case list, phase-2 detail):

- allow: complete phase-1 proposal (all six sections present).
- deny: phase-1 proposal missing the adoption-rationale section.
- allow: complete phase-2 qualification-criteria record (framework_used:
  MEDDPICC, Economic Buyer + Champion named, no advancement claimed).
- deny: record claims stage advancement past initial qualification with an
  empty/TBD Economic Buyer field.
- allow: complete stage-definition record (stage_count in range,
  exit_criteria_present per stage).
- deny: stage-definition record with a rep-activity-verb stage name.
- allow: foreign path (a write outside both target surfaces passes
  untouched, e.g. `docs/issue-<n>/reports/qa.md`).
- allow: kill switch set (`SALES_METHODOLOGY_GATE_OFF=1`) short-circuits
  regardless of content.

### 4. Agents / checklist

**What changes**: nothing new. No agent or checklist file is added.

**Why**: the scout pass found methodology-norms.md names no repeated
multi-step procedure beyond the deliverable-shape checks item 2 already
encodes, and none of the three surveyed sibling rulebooks
(pricing/implementation-rulebook) add a role-specific agent for their own
methodology gate — only core's cross-cutting `warrant` hunt agent, which
`sales/agents/warrant-hunter.md` already references as a canon stub. Adding
an agent here would be inventing a use for the pattern rather than
answering a gap the survey or scout pass actually found.

## Adoption rationale

- Fail-closed trap-at-top, resolved-path regex matching, full-content
  reconstruction for Edit/MultiEdit, and a single missing-list `deny()`:
  sourced from `pricing-rulebook/pricing/hooks/methodology-gate.sh` (lines
  2-3, 46-58, 129-159, 166-218) and cross-confirmed in
  `implementation-rulebook/coding/hooks/coding-progress-gate.sh` (lines
  2-9) — the same shape appearing independently in two sibling rulebooks is
  the scout pass's saturation signal (judge point 1), not a single
  exemplar's idiosyncrasy.
- Record-state sequencing over a bespoke state file: sourced from
  `coding-progress-gate.sh` (lines 144-167, the `resolved_findings` +
  `loop_state: cleared` pattern) and from this repo's own
  `record-fields-gate.sh` header, which already references core's
  `RECORD_FIELDS_TERMINAL_STATES` idiom — extending an idiom already
  present in this repo rather than importing an unrelated one.
- Keyword/regex presence over markdown-structural parsing: sourced from the
  same `methodology-gate.sh` (its six checks are all `has_any(...)`
  substring/keyword tests, no markdown AST) — matches this repo family's
  accepted precision level, so sales does not need to out-engineer its own
  siblings.
- Gate-test harness shape (disposable git repo, stdin JSON, exit-code
  assertion): sourced from `implementation-rulebook/tests/run-gate-tests.sh`
  in full (its `run`/`trailergate`/`progress` helper functions are the
  literal template item 3 above instantiates for sales's own cases).
- No new agent: absence-of-precedent finding — neither surveyed sibling
  rulebook added one for this exact mechanism, and methodology-norms.md
  itself names no repeated procedure that would need one.

## Plugin-reflection plan (phase 2, gated on Approve)

- `sales/hooks/directive.sh`: rewrite `YOU_DECIDE`/`USE_WHEN`/`PRODUCES`/
  `HAND_OFF` per item 1's target shape.
- `sales/hooks/methodology-gate.sh`: new file replacing
  `sales/hooks/record-fields-gate.sh`, per item 2's target shape; update
  `sales/hooks/hooks.json`'s `PreToolUse` command reference accordingly.
- `tests/run-gate-tests.sh`: new file at repo root, per item 3's case list.
- `README.md`'s Layout section: update the `record-fields-gate.sh` bullet
  to describe `methodology-gate.sh` and add a `tests/` bullet.
- No change to `sales/agents/warrant-hunter.md` (stays a core canon
  reference, per this issue's constraint) and no change to
  `docs/issue-1/proposals/methodology-norms.md` (the norm source is
  read-only from this issue's perspective — issue-10 implements it, it
  does not amend it).
- Exact regex/keyword lists, the full phase-1 six-section heading scan
  implementation, and the complete gate-test case set are phase-2
  execution detail, confirmed against the actual gate script being written
  rather than fixed in advance here.
