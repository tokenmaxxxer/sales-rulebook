---
proposal: docs/issue-22/proposals/spec-alignment.md
---

# Hunt record — spec-alignment

## after-proposal — stance 4: assume the write set cannot carry this work — find the path the build will need that the proposal does not list

Verdict: FINDING — step 4's new stage-definitions-gate.sh vocabulary check parses "the deliverable's declared MEDDPICC deal state," but no file (in the write set or anywhere in the repo) defines what label/heading in sales.md actually carries that value — the write set never lists the report-format definition (e.g. a `Deal State:` field, or an update to the methodology-norms proposal / a report template) that would need to exist for the gate to have something to check.
Kind: design-error
Seed: docs/issue-22/proposals/spec-alignment.md (files frontmatter + "What will be done" step 4)
cap_seconds: 60
tier: default
diff_stat_lines: new untracked issue-22 survey and proposal files only
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:05:00Z

### Reproduce
```
grep -n "Stage\|declared\|deal state\|loop_state" sales-stage-definitions/hooks/stage-definitions-gate.sh
grep -rn "Deal State\|deal_state\|MEDDPICC deal state" sales-stage-definitions/ sales-qualification-meddpicc/ docs/handbooks/methodology-plugin-gates.md
```

### Observed
The gate script only recognizes free-form `## Stage N: <name>` headings (the stage-progression rule) — a structurally different axis from a "declared deal state" value. The second grep for any existing "Deal State" / "deal_state" label returns zero matches anywhere in the repo: no report field, no template, no prior convention exists for the gate to read the 5-word vocabulary from.

### Expected
Since step 4 requires the gate to read "the deliverable's declared MEDDPICC deal state" from docs/issue-<n>/reports/sales.md, either the write set must include a file that defines where in the report that value is declared (a labeled field like `Deal State:` alongside the existing `## Stage N:` headings, documented in README/directive.sh or the stage-definitions methodology proposal), or this proposal must specify how the gate derives the value from the existing free-form stage headings it already parses. As written, phase 2 has no source of truth to implement step 4 against.
