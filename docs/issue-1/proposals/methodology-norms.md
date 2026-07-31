# Issue #1 — Proposal: Phase-1 Proposal Norm and Phase-2 Deliverable Norm for `sales`

Status: **proposal only, phase 1**. No directive text, `record-fields`
config, or gates are edited by this document or by this phase. Execution is
phase 2, gated on human Approve per contract v3 s19. Scoped against
`docs/issue-1/reports/sales/current-state-survey.md` and
`docs/issue-1/reports/sales/scout-brief.md`.

## (a) Phase-1 proposal norm

**Methodology**: keep the shape this repo already runs on precedent from
issue-2 and issue-5 (survey-first, then a written proposal with a guiding
principle and a per-item breakdown) — the scout sweep found no external
business-proposal genre (title page/cover letter/pricing) that fits an
internal engineering repo better; codify the in-repo precedent rather than
import one.

**Required sections**, in order:
1. Status banner — phase-1-only, no execution, human-Approve gate reminder.
2. Scope line — names the current-state survey (and scout brief, when
   scouting ran) this proposal is built against.
3. Guiding principle — the one or two sentences that make every per-item
   decision below fall out logically, not a separate justification per item.
4. Per-item breakdown — one subsection per concrete change: what changes,
   why (tied back to the guiding principle), and an illustrative target
   shape (marked non-final where exact wording is TBD for phase 2).
5. Adoption rationale — see (c) below; may be inline per item or a closing
   section, but must be traceable to a source, not asserted as self-evident.
6. Plugin-reflection plan — see (d) below.

**Evidence format**: any claim about "what the field does" (a named
methodology, a required component) must carry a source URL, gathered per the
scout-directive sweep-then-deepen protocol; a claim with no source is
labeled an assumption, not a finding. Claims about *this repo's* current
state are evidenced by file path + line/section reference instead.

## (b) Phase-2 deliverable norm

Covers the three `produces` items from README.md: qualification criteria,
stage definitions, sales playbook.

### Qualification criteria

**Methodology**: MEDDPICC (Metrics, Economic Buyer, Decision Criteria,
Decision Process, Paper Process, Identify Pain, Champion, Competition) as
default. BANT (Budget, Authority, Need, Timing) is retained as an explicitly
named lightweight fallback for short-cycle/simple opportunities — not
silently dropped, since the role's `decides` line covers both.

**Required components**: every qualification-criteria deliverable must
state, per opportunity/segment it covers:
- which of the two frameworks is in effect and why (deal complexity /
  cycle length as the switch)
- a filled-in value or explicit "unknown/blocked" for each field of the
  chosen framework — no framework field may be silently omitted
- for MEDDPICC specifically: Economic Buyer and Champion must be named
  individuals or roles, not "TBD," before an opportunity is allowed to
  advance past initial qualification

### Stage definitions

**Methodology**: entry + exit criteria per stage, exit criteria stated as
completed buyer actions in past tense ("prospect confirmed budget"), never
rep judgment or activity ("had good conversation").

**Required components**:
- 5–7 stages (the surveyed common range for B2B pipelines — enough
  resolution to forecast, not so many it becomes unmanageable)
- ≥2 objective, falsifiable exit criteria per stage
- each stage name is a past-tense/completed action, not a rep activity verb
- a named next-stage handoff for each exit (which stage a deal enters)

### Sales playbook

**Methodology**: multi-section reference document, not a single narrative;
sections are chosen from the surveyed set but scoped down at the marketing
hand-off boundary this role already declares.

**Required components** (sections that must all be present):
1. Process overview — the stage definitions above, referenced not restated
2. Qualification framework — the criteria above, referenced not restated
3. ICP / buyer persona summary — who the deal is qualified against
4. Objection-handling / competitive notes — ties to MEDDPICC's Competition
   field
5. Metrics — conversion rate per stage, average cycle length, at minimum

**Explicitly out of scope** (hand off to `marketing` per README.md): full
messaging scripts, positioning copy, lead-generation content — the playbook
may reference marketing's assets by name/link, never duplicate their
content.

## (c) Adoption rationale

- MEDDPICC over BANT-only or MEDDIC-only: this role's declared decision
  (리드/기회를 어떻게 진행시킬지 — how to progress a lead/opportunity) is
  precisely the falsifiable-progression judgment MEDDPICC's extra fields
  (Paper Process, Competition) are designed to make explicit; BANT alone
  cannot represent "stalled in procurement" or "losing to an unidentified
  competitor," both real progression-blocking states. Source: SalesHive,
  Spotlight.ai (see scout-brief Sources).
- Past-tense, buyer-action exit criteria over rep-judgment criteria: sourced
  best-practice claim ("if you cannot write down two objective things...
  that stage is not a stage, it is a mood") directly prevents the failure
  mode of an ungoverned pipeline — deals sitting in a stage indefinitely
  with no falsifiable trigger to move or kill them, which is the same
  ungoverned-judgment risk this whole rulebook exists to close. Source:
  Avoma.
- Multi-section playbook over single-document narrative: every surveyed
  exemplar (Zendesk, Salesforce, Skaled) treats playbook sections as
  distinct components, and a component list is what makes a `record-fields`
  gate checkable in phase 2 (see (d)) — a single free-text document cannot
  be validated for completeness the way a section checklist can.
- In-repo proposal shape over generic business-proposal genre: issue-2 and
  issue-5 already establish and pass review under this shape; there is no
  reason to hold this role's phase-1 documents to a different, externally-
  sourced genre when a working local precedent exists and this repo's own
  audience (a human approver reading a PR, not a customer) doesn't match
  the customer-facing proposal genre's audience.

## (d) Plugin-reflection plan (phase 2, gated on Approve)

- **`sales/hooks/directive.sh`**: extend the `PRODUCES` heredoc string to
  name the three required deliverable methodologies explicitly (e.g.
  `"PRODUCES: sales playbook (see playbook sections), stage definitions
  (entry/exit criteria), qualification criteria (MEDDPICC/BANT)"`) so the
  SessionStart directive itself carries the methodology name, not just the
  deliverable noun.
- **`record-fields` required keys**: core's `record-fields-gate.sh` (per
  `docs/issue-2/proposals/canon-reference-conversion.md`) is parameterized
  per role; phase 2 should add a sales-specific required-field list for the
  record (`docs/issue-<n>/reports/sales.md`) whenever a deliverable of one
  of the three kinds is produced — minimally: `framework_used` (MEDDPICC |
  BANT), `stage_count`, `exit_criteria_present` (bool per stage). Exact
  core config surface (path/format) is unverified from this repo and must
  be confirmed against core's actual `record-fields-gate.sh` contract before
  phase 2 lands it.
- **Gate**: a phase-2 completion gate that fails the record if any stage
  definition has 0 or 1 exit criteria, or if a qualification-criteria
  deliverable has an empty Economic Buyer/Champion field on an opportunity
  past initial qualification — mirrors core's existing pattern of gating
  on record-field presence rather than prose review.
- Scope explicitly excludes touching `warrant-hunter.md` (stays a core
  canon reference per this issue's constraint) and excludes writing the
  actual record content — record-writing is phase-2 execution, not this
  proposal.
