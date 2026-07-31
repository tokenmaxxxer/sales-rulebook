#!/usr/bin/env bash
# Sourced fragment (not a standalone hook) — sales/hooks/directive.sh composes
# this into the SessionStart banner. Owns the phase-1 proposal norm facet.
SALES_PROPOSAL_NORM_FRAGMENT="USE_WHEN (phase-1 proposal norm): a docs/issue-<n>/proposals/*sales*.md write must contain, in order: (1) status banner (phase-1-only, human-Approve gate reminder), (2) scope line naming the current-state survey/scout-brief, (3) guiding principle, (4) per-item breakdown, (5) adoption rationale with sourced claims, (6) plugin-reflection plan. Enforced by sales-proposal-norm's PreToolUse gate. Kill switch: SALES_PROPOSAL_NORM_GATE_OFF=1."
