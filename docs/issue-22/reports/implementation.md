---
subject: issue-22
role: implementation
code_under_review: HEAD
loop_state: landed
---

# Phase-2 record — spec-alignment (MEDDPICC verdict field + 5-word loop_state vocab)

## What was done

Per approved `docs/issue-22/proposals/spec-alignment.md`:

1. `sales-qualification-meddpicc/hooks/qualification-gate.sh`: added
   `verdict` as a 9th checked MEDDPICC field (presence-only, same rule as
   the other required fields — value or explicit unknown/blocked marker).
   Split `MEDDPICC_FIELDS` into `MEDDPICC_REQUIRED_FIELDS` (7: Metrics,
   Economic Buyer, Decision Criteria, Decision Process, Identify Pain,
   Champion, Verdict) and `MEDDPICC_OPTIONAL_FIELDS` (2: Paper Process,
   Competition — may be omitted entirely, but a declared label without a
   captured value still denies).
2. `sales-qualification-meddpicc/README.md` + `hooks/directive.sh`:
   documented the 9-field/7-required-2-optional split and named
   `reference_resolution`/`recomputation` as spec rules this gate does not
   enforce (external hook / issue-521 follow-up respectively).
3. `sales-qualification-meddpicc/tests/run-gate-tests.sh`: added cases for
   verdict presence/absence and optional-field omitted-vs-label-only-no-value;
   fixed two pre-existing fixtures (`MEDDPICC_MISSING_PAPER` stale name,
   kill-switch-typo case) that the field-relaxation would have otherwise
   made silently pass for the wrong reason.
4. `sales-stage-definitions/hooks/stage-definitions-gate.sh`: added an
   optional, document-scoped `Deal state: <value>` label
   (label-adjacent-value-capture) with a fixed 5-word vocabulary check
   (`qualifying`, `negotiating`, `landed`, `economic-buyer-undeclared`,
   `deal-unreachable`), alongside the existing unchanged `## Stage N: <name>`
   structural check.
5. `sales-stage-definitions/README.md` + `hooks/directive.sh`: documented
   the vocabulary and its explicit distinctness from core's
   report-frontmatter `loop_state` field.
6. `sales-stage-definitions/tests/run-gate-tests.sh`: added allow cases for
   each of the 5 words, a deny case for a stale/unlisted word, and an allow
   case for no `Deal state:` label declared at all.
7. `docs/handbooks/methodology-plugin-gates.md`: cross-referenced
   `roles/specs/sales.spec.json` as source of truth for the 9-field list
   and 5-word vocabulary, and updated the per-gate summary bullets.

## Why

Align this rulebook's vocabulary/rules with `roles/specs/sales.spec.json`
per the approved proposal, without deleting existing methodology and
without building the two spec rules (`recomputation`, `reference_resolution`)
the spec itself marks TBD/out-of-scope.

## Upstream basis

- `docs/issue-22/proposals/spec-alignment.md` (approved).
- `roles/specs/sales.spec.json` — the spec being aligned to.
- Approved via issue comment `APPROVE issue-22/implementation`
  (single-account mode, JiwonJung94, an approvers.md account), opening
  phase 2 per contract v3 s19.

## What did not work

- Two of the new/edited qualification-plugin test fixtures
  (`MEDDPICC_MISSING_PAPER` reused for the kill-switch-unrecognized-value
  case) initially still asserted `deny`, but after relaxing Paper
  Process/Competition to optional the fixture content became independently
  valid — the kill-switch case would have passed for the wrong reason
  (content validity, not kill-switch bypass). Fixed by pointing that case
  at `MEDDPICC_MISSING_VERDICT` (still invalid on the required `verdict`
  field) instead.
- Initial test runs showed 7-8 gate-test failures; traced to this session's
  own `CLAUDE_ROLE=implementation` environment variable leaking into the
  test harness's subshells and short-circuiting the gate's
  `[ "$role" = "sales" ] || exit 0` role check. Confirmed pre-existing (same
  failures reproduce on the unmodified base branch) and environment-only —
  worked around for verification by running the harnesses with
  `env -u CLAUDE_ROLE`. No repository change was needed or made for this.

## Run and result

    env -u CLAUDE_ROLE bash sales-qualification-meddpicc/tests/run-gate-tests.sh
    -> Results: 22 passed, 0 failed

    env -u CLAUDE_ROLE bash sales-stage-definitions/tests/run-gate-tests.sh
    -> Results: 27 passed, 0 failed

## Open findings

None blocking. Pre-existing, out-of-scope-for-this-issue items noted for
awareness only:

- The gate test harnesses are sensitive to an ambient `CLAUDE_ROLE`
  environment variable when run from a non-sales role's session (see
  "What did not work" above) — a harness/environment hygiene item, not a
  gate defect, and not part of this proposal's write set.
- `verdict.recomputation` and `reference_resolution` remain named-but-
  unenforced per the approved proposal's Out of scope (issue-521
  follow-up; external `role-spec-reference-guard.sh` hook respectively).
