# Issue #19 — Current-state survey (sales)

Status: phase-1 survey only. No code/hook/test changed by this document.

## Blocker text (issue #19)

> core #78 랜딩 후: stub-check 공인 형식에 맞춰 directive 조합 정합(또는 공인된
> 현행 유지 확인), run-stub-check green 검증

## 1. core #78 landing check

core issue #78 ("stub-check 공인 조합 형식 + compliance-check 스캔 범위 확장") is
**CLOSED**, delivered via `tokenmaxxxer-core` PR #80 (propose) and PR #81
(deliver, merged), commit `8ba60f1`. Verified against a fresh clone of
`tokenmaxxxer/tokenmaxxxer-core` `main` (no local core repo was writable —
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core` is a read-only mount).

`core/hooks/tests/stub-check.sh` now reads `canon-forms.txt` (new file, next
to the script) to build `CANON_FORM_PATTERNS`, used to exempt lines in a
role's `directive.sh` from the "regrown boilerplate" fail. The manifest
registers exactly two shapes:

```
single-call:^[[:space:]]*core_role_directive[[:space:]]
fragment-loop:^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=\(
fragment-loop:^[[:space:]]*for[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]+
fragment-loop:^[[:space:]]*done[[:space:]]*$
```

`compliance-check.sh`'s scan-scope widening (item 2 of #78) is a core-side
change (hooks.json PreToolUse enumeration replacing filename-glob matching)
with no sales-side file to adjust; nothing under `sales/` matched the old
glob gap (`*-gate.sh`) in a way that needs a local follow-up. Confirmed by
reading core's compliance-check.sh scan-target logic in the same fresh
clone — it now walks `core/hooks/hooks.json`'s registered `PreToolUse`
entries directly rather than a `*-gate.sh` glob, which is a core-only file.

## 2. run-stub-check result against this rulebook, today

Ran `sales/hooks/tests/run-stub-check.sh` with `CORE_PLUGIN_ROOT` pointed at
the fresh core clone (`main` @ `8ba60f1`):

```
stub-check: ok — no vendored 'trailer-gate.sh' under sales/hooks/tests/..
stub-check: ok — no vendored 'record-fields-gate.sh' under sales/hooks/tests/..
stub-check: ok — no vendored 'handbook-trigger-gate.sh' under sales/hooks/tests/..
stub-check: ok — no vendored 'parse-check.sh' under sales/hooks/tests/..
stub-check: ok — no vendored 'stub-check.sh' under sales/hooks/tests/..
stub-check: ok — no vendored 'gate-lib.sh' under sales/hooks/tests/..
stub-check: ok — no vendored 'gate-lib.py' under sales/hooks/tests/..
stub-check: ok — no vendored 'compliance-check.sh' under sales/hooks/tests/..
stub-check: FAIL — sales/hooks/tests/../directive.sh: has non-stub line(s), looks like regrown boilerplate:   "$HERE/../../sales-proposal-norm/hooks/directive.sh" \
EXIT_CODE:1
```

Still **RED**. name-consistency-check.sh (the sales-local second stage of
`run-stub-check.sh`, issue-16 (d)) never runs because `set -euo pipefail`
stops the wrapper at the first non-zero exit.

## 3. Root cause

`sales/hooks/directive.sh:16-23` (issue-10-approved fragment-composition
loop, unchanged since landing):

```bash
for frag in \
  "$HERE/../../sales-proposal-norm/hooks/directive.sh" \
  "$HERE/../../sales-qualification-meddpicc/hooks/directive.sh" \
  "$HERE/../../sales-stage-definitions/hooks/directive.sh" \
  "$HERE/../../sales-playbook/hooks/directive.sh"
do
  [ -f "$frag" ] && . "$frag" 2>/dev/null
done
```

`stub-check.sh`'s structural check flags every non-blank/non-comment line of
`directive.sh` that isn't the `role-directive.sh` source line, an
`VAR=value` assignment, or the `core_role_directive` call, then tries to
excuse each flagged ("other") line against `CANON_FORM_PATTERNS` one line at
a time. The registered `fragment-loop` shape only excuses three line
*shapes*: an array-assignment opener (`NAME=(`), the `for ... in ...`
header, and `done`. It has **no pattern for the loop's body** — neither the
per-line path-continuation values inside the `for frag in \ ... ` list
(sales's actual approved form, issue-10) nor a body statement doing the
conditional source (`[ -f "$frag" ] && . "$frag" ...`, needed so a missing
sibling methodology plugin doesn't fail closed, per directive.sh's own
comment). Every one of those lines is still flagged as "regrown
boilerplate" and fails the check.

This is not a drift regression on sales's side: `directive.sh` is byte-identical
in intent and structure to what issue-10 designed and got merged, and core
issue #78's own background text explicitly cites *this* loop
(`for frag in ...`) as the reason canon needed a `fragment-loop` shape at
all. The shape core actually registered covers the loop's header/footer but
not a body capable of doing anything — no `for` loop that both (a) iterates
literal path values (not a pre-built array variable, since sales's approved
form lists paths inline after `for frag in \`) and (b) does real
conditional work in its body can pass with only those three patterns. A
minimal literal reproduction (single-line array + no-op body) would still
fail on the source line inside the loop.

## 4. What is NOT in scope here

- `sales/hooks/hooks.json` — unaffected; not part of this FAIL.
- `compliance-check.sh` scan-scope (#78 item 2) — core-only, already landed,
  nothing local to adjust.
- Any sales-side rewrite that changes the *composition design* itself
  (issue-10's fragment order, kill-switch, or per-plugin fragment
  variables) — out of scope; issue #19 only asks to close the canon-form
  mismatch or propose an adjustment, not to revisit issue-10's design.

See `scout-brief.md` for the (skipped, with reason) scouting pass and
`../proposals/canon-form-alignment.md` for the recommended fix.
