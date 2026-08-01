# Issue #19 — Scout brief (sales)

Mode: single-angle, single-stage (narrow technical scope — see below).

## Angle run

Not a product-shaped deliverable with a field of comparable products to
survey. The open decision is narrow and technical: how to close a
regex-manifest gap in a shared core script. Ran one scout angle instead of
a full multi-angle sweep — precedent search inside `tokenmaxxxer-core`
(fresh clone, `main` @ `8ba60f1`) for (a) any other canon-forms-style
manifest that excuses a multi-line loop *body*, and (b) any other role
plugin in the org that composes multiple directive fragments the way
`sales/hooks/directive.sh` does, which would be prior art for how to shape
a fix.

- (a) `core/hooks/tests/canon-manifest.txt` (the sibling manifest
  stub-check.sh also reads) is a flat filename list, not a
  pattern-with-body scheme — no precedent for a "loop body" pattern
  shape there. Grepped all of `core/hooks/` for `for ` loops
  (`core/hooks/tests/deny-only-check.sh:76`,
  `core/hooks/tests/run-gate-lib-tests.sh:144,246`,
  `core/hooks/handbook-trigger-gate.sh:107-108`,
  `core/hooks/board-gate.sh:146,160,170,200`) — all are inside core's own
  canon scripts (exempt from stub-check by definition, per
  `stub-check.sh`'s own comment: "core is canon by definition ... not
  run against directly"), none is an example of a *rulebook-side*
  `directive.sh` loop that stub-check needs to excuse.
- (b) No sibling rulebook plugin composes multiple methodology-plugin
  directive fragments the way `sales` does — `sales`'s fragment-loop
  (issue-10) is the sole reason core issue #78 added the `fragment-loop`
  shape at all (core issue #78 background text names this exact loop).
  There is no second real-world instance to check the registered pattern
  against, which is consistent with the survey's finding that #78's
  author had only the *header/footer* shape in view and missed the body.

## Conclusion

No exemplar or precedent exists elsewhere in the org for a working
loop-body exemption; the gap identified in `current-state-survey.md` is not
something already solved by another role or another core manifest entry.
The fix is a follow-up defect against core's own `canon-forms.txt`
(concrete pattern, source-line addressed in the proposal), not a design
choice with multiple viable shapes to weigh against a competitive field.
Further scouting stages would not change this — stopping at one stage.

Sources:
- https://github.com/tokenmaxxxer/tokenmaxxxer-core (main @ 8ba60f1, fresh clone) — `core/hooks/tests/stub-check.sh`, `core/hooks/tests/canon-forms.txt`, `core/hooks/tests/canon-manifest.txt`, `core/hooks/*.sh`
- https://github.com/tokenmaxxxer/tokenmaxxxer-core/issues/78
- https://github.com/tokenmaxxxer/tokenmaxxxer-core/pull/81
