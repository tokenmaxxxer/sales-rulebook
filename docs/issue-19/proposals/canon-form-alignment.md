# Issue #19 — Proposal: close the stub-check canon-form mismatch

Status: **proposal only, phase 1**. No directive/hook/test file is edited by
this document. Execution is phase 2, gated on human Approve per contract v3
s19. Scoped against `../reports/sales/current-state-survey.md` and
`../reports/sales/scout-brief.md`.

## Problem restated

`run-stub-check.sh` is still RED after core #78 landed
(`current-state-survey.md` §2-3): core's new `canon-forms.txt` registers a
`fragment-loop` shape that excuses only the loop's header (`NAME=(` or
`for ... in ...`) and footer (`done`), never a body line. `sales`'s
issue-10-approved composition loop (`sales/hooks/directive.sh:16-23`) —
the exact loop #78's own background text cites as the reason the shape was
added — necessarily has a body (the conditional source,
`[ -f "$frag" ] && . "$frag" 2>/dev/null`, needed so a missing sibling
methodology plugin doesn't fail closed). No form of that loop can pass with
only a header/footer exemption. This is a gap in core's #78 delivery, not
directive.sh drifting from its approved design.

## Recommendation: file a core follow-up, no sales-side file change

Do **not** rewrite `sales/hooks/directive.sh`. Its structure is unchanged
from issue-10's approved design and remains the correct shape for this
role's composition need (order-fixed, missing-sibling-tolerant, no
fail-closed on an absent methodology plugin). Rewriting it to dodge the
gap (e.g. collapsing the loop into unrolled `[ -f ... ] && . ...` calls
per fragment, or moving the conditional-source into an core-lib helper
function called once per fragment outside a loop) would re-encode
loop-shaped logic as repeated non-loop boilerplate — worse by the same
"regrown boilerplate" standard #78 exists to catch, and would silently
undo issue-10's reviewed design to satisfy a manifest gap instead of
fixing the manifest.

Concretely: **open a follow-up issue against `tokenmaxxxer-core`**
(same shape as #78: background + a one-line manifest fix) asking for one
more `fragment-loop` pattern line covering the loop-body source
statement, e.g.

```
fragment-loop:^[[:space:]]*\[[[:space:]]*-f[[:space:]].*\][[:space:]]*&&[[:space:]]*\.[[:space:]]
```

(matches `[ -f "$frag" ] && . "$frag" ...` — the conditional-source body
form; core owns the exact regex and any tightening it wants, this is the
minimal shape needed). Reference core issue #78 and this issue (#19) as
the trigger. Sales does not have write access to core's canon files (core
canon is explicitly "never vendored into a rulebook" per
`stub-check.sh`'s own header comment) — the fix has to land there.

## Phase-2 scope once this is filed

Phase 2 for issue #19 is: file the core follow-up issue, and once it lands
(same "core lands → sales verifies" shape as issue #19 itself required for
#78), re-run `run-stub-check.sh` and confirm green; record both the filed
issue link and the green run in `docs/issue-19/reports/sales.md`. If core's
approver instead prefers a different resolution (e.g. a narrower pattern,
or a request that sales restructure the loop a specific way), phase 2
adapts to that decision rather than pre-committing to the regex above.

No `sales/hooks/directive.sh` or `sales/hooks/hooks.json` change is
proposed by this document. `name-consistency-check.sh` (the sales-local
issue-16 (d) stage) is untested by this run since `run-stub-check.sh` stops
at the first non-zero exit (`set -euo pipefail`); it is unaffected by this
gap and needs no separate verification once the core-side fix lands and
the wrapper's first stage passes.
