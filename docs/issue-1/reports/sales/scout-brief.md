# Issue #1 — Scout Brief (sales)

Mode: parallel WebSearch, 4 angles in one round (Stage 1), one synthesis
judge point (Stage 2). Saturation reached after Stage 2 — angles converged
cleanly onto the survey's three gap items (qualification criteria, stage
definitions, playbook), so no further deepening round changes a build
decision. Total: 2 stages, well under the 5-stage/3-min budget.

## Angles run

1. Sales qualification methodology (BANT/MEDDIC/MEDDPICC)
2. Sales pipeline stage definition / exit-criteria practice
3. Sales playbook template structure
4. Business proposal document standard sections

## Category must-bes (Kano)

- Qualification criteria must be a **named, checkable framework**, not ad-hoc
  notes — BANT (4-field, fast/simple) or MEDDIC/MEDDPICC (6-8 field, deep) are
  the industry-standard choices; picking neither is the actual anti-pattern.
- Stage definitions must carry **objective, past-tense exit criteria** per
  stage ("prospect confirmed budget"), not activity/mood descriptions
  ("had good conversation") — this is the single most-repeated correctness
  criterion across sources.
- A sales playbook must cover process + criteria + messaging + metrics as
  distinct sections, not a single narrative document.
- A proposal document (any domain) must separate problem/background from
  proposed solution from rationale — evidence-for-the-choice is expected to
  be its own visible unit, not folded into the narrative.

## Performance axes competitors visibly differ on

1. **Qualification depth vs. speed**: BANT (fast, SMB/simple deals) vs.
   MEDDIC/MEDDPICC (deep, multi-stakeholder/enterprise, adds Paper Process +
   Competition to explicitly cover procurement-stall and competitor-blindspot
   failure modes).
2. **Stage-criteria objectivity**: best practice is falsifiable, buyer-action
   criteria ("two objective things must be true to leave a stage") vs. rep
   subjective judgment.
3. **Playbook scope**: broad (org/product/persona/process/messaging/metrics,
   HubSpot/Zendesk/Salesforce style) vs. narrow (script-only). Broad wins
   reviews; narrow reads as incomplete/stale fast.

## Adopt / skip

- **Adopt**: MEDDPICC as the default qualification methodology (an
  extension of MEDDIC, superset of BANT's fields) — the role's own
  `decides` (리드/기회를 어떻게 진행시킬지) is exactly the deal-progression
  judgment MEDDPICC's fields are built to make explicit and falsifiable
  (Economic Buyer, Decision Process, Paper Process, Champion). BANT is kept
  as a documented lightweight-mode fallback, not silently dropped, since
  simple/short-cycle leads are a real case the role handles too.
- **Adopt**: past-tense, buyer-action exit criteria per stage, and a
  requirement of ≥2 objective exit conditions per stage (repo currently has
  zero of this specified).
- **Adopt**: multi-section playbook structure (org/process context, product,
  ICP/persona, stage-by-stage process with entry/exit criteria, qualification
  framework, messaging assets, metrics) rather than a single free-text doc.
- **Skip**: lead-generation and messaging-script content sections that
  properly belong to `marketing` per this role's own hand-off line — playbook
  should reference, not duplicate, marketing's messaging assets.
- **Skip**: generic business-proposal template sections (title page, cover
  letter, pricing/terms) — those are external-facing customer-proposal norms,
  not a fit for this repo's *internal* phase-1 proposal, which already has a
  working in-repo precedent (issue-2/issue-5 shape) that should be codified
  instead of importing an unrelated document genre.

## Gap line (from current-state survey)

Repo has zero of: a named qualification framework, exit-criteria discipline,
or playbook required-components list. It does have a working internal
proposal *shape* (survey → guiding principle → per-item breakdown, phase-1
banner) from issue-2/issue-5 precedent — that shape is adopted as the
phase-1 proposal-document norm itself rather than re-derived from external
business-proposal genre conventions, which don't fit an internal engineering
repo.

## Segment fit

This is an internal AI-agent rulebook repo, not a customer-facing sales org
— methodology depth should match "role decides deal-progression judgment
and hands off messaging," which MEDDPICC + objective stage gates address
directly; heavier enterprise-CRM tooling concepts (territory planning,
comp plans) are out of scope and not adopted.

Sources:
- https://www.spotlight.ai/post/sales-qualification-frameworks-compared-meddpicc-bant-sandler-and-spice
- https://www.salesforce.com/blog/sales/bant-vs-meddic/
- https://saleshive.com/blog/b2b-sales-qualification-frameworks-bant-to-meddpicc
- https://www.avoma.com/blog/sales-pipeline-stages
- https://www.digitalapplied.com/blog/sales-pipeline-stage-definitions-2026-crm-framework
- https://www.zendesk.com/blog/sales-playbook/
- https://www.salesforce.com/blog/sales/sales-playbook/
- https://skaled.com/insights/what-to-include-sales-playbook/
- https://pressbooks.bccampus.ca/businesswritingessentials2/chapter/13-4-common-sections-in-proposals/
