# Survey — issue-22 spec alignment

Scout skip: spec (`roles/specs/sales.spec.json`) is fully prescriptive — field
names, types, and loop_state words are all given verbatim by the spec author.
No external/product design decision is open; only internal placement
decisions, which this survey (not external scouting) resolves. Skip condition:
"spec leaves no design decision open" (methodology vocabulary side).

## Spec required fields vs current repo

All 8 MEDDPICC field names (`metrics`, `economic_buyer`, `decision_criteria`,
`decision_process`, `paper_process`, `identify_pain`, `champion`,
`competition`) already appear verbatim as the `MEDDPICC_FIELDS` list in
`sales-qualification-meddpicc/hooks/qualification-gate.sh:226-234`, and are
spelled out in `sales-qualification-meddpicc/README.md:3`. Currently all 8 are
enforced as equally required (no optional/required split); spec marks
`paper_process` and `competition` optional.

`verdict` (enum qualified/disqualified) does not exist anywhere in the repo.
The gate only flags missing/TBD fields; it never computes or requires an
aggregate verdict value.

`reference_resolution` (economic_buyer/champion must resolve to a named
contact) is partially covered: `qualification-gate.sh:245-258` requires
EB/champion to be non-TBD only once the record claims "advanced past initial
qualification" — narrower than the spec's unconditional "no orphan
references" rule, and the spec's actual enforcement lives in an external hook
(`role-spec-reference-guard.sh`) not present in this repo.

`recomputation` (verdict = worst-case completeness across all 8 fields) is
explicitly marked `TBD` / out-of-scope by the spec itself
(issue-521 follow-up note) — nothing to enforce yet.

## loop_state vocabulary vs current repo

The report-frontmatter `loop_state` field used across `docs/issue-*/reports/`
(e.g. `docs/issue-19/reports/sales.md:3` -> `landed`) is core's generic
record-workflow state (contract v3 §2), not a deal-progression concept. Grep
across the repo for the spec's 5 words found: `landed` used generically
(overlap only in spelling, not semantics); `qualifying`, `negotiating`,
`economic-buyer-undeclared`, `deal-unreachable` do not appear anywhere.
Other frontmatter values seen (`open`, `cleared`, `phase-1`) belong to core's
unrelated record-workflow axis, not sales deal-stage vocabulary — not "stale
MEDDPICC vocabulary," a different axis entirely.

`sales-stage-definitions/hooks/stage-definitions-gate.sh:134-136` enforces
free-form `## Stage N: <name>` headings (5-7 stages, any names) — zero fixed
vocabulary today. This is the only plugin regulating deal-stage progression,
making it the natural home for a fixed loop_state vocabulary check, distinct
from core's report-frontmatter `loop_state` (same field name, different
concept — this ambiguity must be called out explicitly in the docs to avoid
confusion, not silently overloaded).

`docs/issue-2/proposals/canon-reference-conversion.md:118` already flagged
"this repo's seed has no loop-state handling" for role-specific terminal
states as an open, unaddressed gap — confirms issue-22 is closing a
previously known hole.

## Unrelated plugins (confirmed out of scope)

`sales-playbook` and `sales-proposal-norm` check structural sections/shape
only (playbook's "metrics" is a playbook section, not the MEDDPICC field);
neither references MEDDPICC fields or loop_state.
