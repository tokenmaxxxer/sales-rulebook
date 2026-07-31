---
subject: issue-10
role: sales
---

# Current-state survey

Scope: what `sales` currently enforces mechanically, versus what issue-1's
adopted methodology norms (`docs/issue-1/proposals/methodology-norms.md`)
still leave as prose only, ahead of proposing issue-10's enforcement layer.

## What already exists (post issue-1 phase 2, PR #9)

- `sales/hooks/directive.sh` — `PRODUCES` is one dense line naming the three
  deliverable kinds and their required shapes (MEDDPICC/BANT, 5-7 stages,
  playbook sections). No `USE_WHEN`/phase-specific elaboration; no
  phase-1-vs-phase-2 distinction at all in the directive text.
- `sales/hooks/record-fields-gate.sh` — PreToolUse gate on
  `docs/issue-<n>/reports/sales.md` only. Checks three keyword-presence
  conditions: if the record mentions qualification criteria/MEDDPICC/BANT,
  requires the literal string `framework_used`; if it mentions stage
  definitions, requires `stage_count` and `exit_criteria_present`. This is
  presence-of-keyword checking, not structural validation — a record could
  contain `framework_used` as a bare word with no value and still pass.
- No gate targets `docs/issue-<n>/proposals/*.md` (phase-1 write surface) at
  all — only the phase-2 record path is covered.
- No order/state-tracking gate anywhere in this plugin.
- `sales/hooks/tests/run-stub-check.sh` — wraps core's generic drift check;
  no gate-specific pass/fail test cases exist in this repo (no `tests/` at
  repo root).
- `sales/agents/warrant-hunter.md` — reference stub to core's `warrant`
  hunt agent; no sales-specific agent or checklist exists.

## Gaps against issue-10's four asks

1. **Directive depth**: current `PRODUCES` line is a summary, not a
   facet-level executable instruction (no per-facet judgment criteria, no
   explicit prohibitions, no phase split). Confirmed gap.
2. **Methodology gate**: exists only for the phase-2 record path, and only
   checks three field-name keywords rather than the full component list
   methodology-norms.md (b) actually requires (e.g. nothing checks for
   ≥2 exit criteria per stage, past-tense stage naming, or Economic
   Buyer/Champion named-not-TBD). Nothing gates the phase-1 proposal write
   surface's six required sections (methodology-norms.md (a)). Confirmed
   gap, and the one sequencing rule the norms document states explicitly —
   Economic Buyer/Champion must be named before an opportunity advances
   past initial qualification — has no state-tracking enforcement.
3. **Gate tests**: none exist at repo root. Confirmed gap.
4. **Agents/checklist**: methodology-norms.md names no repeated procedural
   loop distinct from the deliverable-shape checks already covered by (2);
   `warrant-hunter.md` already covers the cross-cutting hunt loop as a core
   canon reference. Tentative: no new agent needed, to be confirmed against
   comparable in-repo rulebooks in the scout pass below.

## Write surfaces this proposal's plugin-reflection plan must name

- `sales/hooks/directive.sh` (directive depth)
- `sales/hooks/record-fields-gate.sh` (extend) or a new
  `sales/hooks/methodology-gate.sh` (new, phase-1 proposal surface +
  richer phase-2 checks) — which one is a phase-1 open decision informed by
  precedent, see scout-brief.
- `sales/hooks/hooks.json` (wiring for any new gate script)
- `tests/` at repo root (new)
