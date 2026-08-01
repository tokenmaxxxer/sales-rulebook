# issue-13 current-state survey: sales gate scripts vs. 2026-08-01 audit (grade A-)

Subject: issue-13. Scope: the four sales-*/hooks/*-gate.sh scripts
(sales-qualification-meddpicc, sales-proposal-norm, sales-stage-definitions,
sales-playbook) and their tests/run-gate-tests.sh harnesses, plus
sales/README.md-equivalent docs across the four plugins.

## Scout skip record

Scouting (external exemplar sweep) skipped. Reason: the issue names a
specific, already-designed adoption target (core issue #72's
`core/hooks/lib/gate-lib.sh` / `gate-lib.py` and
`docs/handbooks/gate-house-standard.md`) and a closed defect list — there is
no external product category to benchmark against; the one open design
question (how to implement section/adjacency structural parsing for
semantic checks) is an internal parsing-technique choice with no comparable
consumer-product exemplar, resolved by engineering judgment in the proposal
below.

## 1. Precondition check: is core issue #72 landed?

`docs/specs/role-handoff-contract.md`'s board rule: state is read from
`main`, never an open PR. Checked `tokenmaxxxer-core`'s `origin/main` HEAD:

```
146a129 propose(implementation): gate-house standard canonization ... (#73)
```

This is the **phase-1 proposal** commit only (docs, no code — confirmed via
`git show --stat`: only three files under `docs/issue-72/...` and
`docs/decisions/...`, zero files under `core/hooks/`). A phase-2 "deliver"
commit (`5550961`) exists in that role's local worktree/branch
(`issue-72/implementation`) but is **not on `origin/main`** — the branch
has diverged, unpushed.

**Conclusion: the issue's stated precondition ("core issue #72 landed") is
not yet satisfied on the board.** `core/hooks/lib/gate-lib.sh` and
`gate-lib.py` do not exist on core's `main`. This proposal is written to
consume that library by its documented interface (stable per the core
worktree's docstrings) but cannot be executed as code until core#72 phase 2
merges. Phase 1 here (survey + proposal only) does not require the library
to exist; phase 2 does, and must re-check `origin/main` before starting.

## 2. gate-lib.sh / gate-lib.py interface (read from core#72's worktree, not merged)

Shell (`core/hooks/lib/gate-lib.sh`):
- `gate_trap_fail_closed` — installs the fail-closed EXIT trap; must be the
  first statement, before `set -uo pipefail`.
- `gate_kill_switch_active "$VALUE"` — returns 0 (stay active) for
  empty/off-spelling/**unrecognized value**; returns 1 (disable) only for a
  recognized on-spelling (1/true/yes/on, case-insensitive). This fixes
  exactly the kill-switch defect class the issue cites generically for
  core's own canon — the sales gates below have the *same* bug shape.
- `gate_deny "<name>" "<msg>"` / `gate_allow` — stderr-only deny, exit 2/0.
- `gate_bash_write_targets "<cmd>"` — token-scan for Bash-tool writes (not
  needed by the sales gates today; they only match Write/Edit/MultiEdit).

Python (`core/hooks/lib/gate-lib.py`), loaded via `importlib` using env var
`GATE_LIB_PY` (exported by the shell lib):
- `gate_parse_json_or_deny(raw, deny)` — malformed-JSON-deny, empty-payload-
  deny, non-object-deny.
- `gate_normalize_path(root, path)` — pure string/path algebra, absolute or
  relative or `./`-prefixed, returns root-relative POSIX tail or `None` if
  outside root. Does not touch the filesystem (no realpath) — callers doing
  symlink-safe resolution against a live project root still realpath their
  own `root` first, exactly as the sales gates' existing `resolve()` does.
- `gate_reconstruct_write(tool, tool_input, current_content)` — Write /
  Edit (`replace_all`-aware) / MultiEdit (per-edit `replace_all`-aware) /
  NotebookEdit (insert|replace cell source). Returns `(new_text, ok)`;
  `ok=False` means fail-closed-deny, never a silent pass.

No semantic/structural (section, adjacency) checking exists in gate-lib —
that is out of scope for the shared library by design (it is inherently
role/methodology-specific) and stays each rulebook's own responsibility.

## 3. Defects confirmed by reading the sales gates directly

### 3a. `sales-qualification-meddpicc/hooks/qualification-gate.sh`

- **Substring-match semantic check (issue defect 1).** Lines 156-169,
  184-187: `has_any()` is `any(nd in low for nd in needles)` over the
  **entire lower-cased document**, not a section. A MEDDPICC field is
  marked "present" if its name/synonym appears *anywhere* in the doc —
  including prose like "we lost this deal due to **competition** from
  Acme" with no actual Competition field, or a field name mentioned in an
  unrelated methodology-discussion paragraph. This exactly matches the
  issue's "'competition' 산문 통과" (competition-mentioned-in-prose-passes)
  example.
- **TBD-detection is adjacency/formatting-brittle (issue defect: 공백
  민감).** Lines 195-196: `eb_tbd` requires the literal substring
  `"economic buyer: tbd"` or `"economic_buyer: tbd"` (single space after
  colon, lower-cased). `"Economic Buyer:  TBD"` (two spaces),
  `"Economic Buyer:\nTBD"` (field label and value on separate lines — a
  common markdown table/list rendering), or `"Economic Buyer - TBD"` all
  fail to match `eb_tbd`, so the gate reads the field as **filled** when it
  is actually TBD, defeating exactly the check the issue's approval
  addendum (issue-1) added.
- **No absolute-path normalization gap found in this file** beyond the
  existing `resolve()` (uses `os.path.realpath` + `posixpath.normpath`,
  already reasonably defensive) — but it duplicates logic gate-lib.py's
  `gate_normalize_path` now centralizes; keeping a local reimplementation
  is itself the "자체 재구현" the issue's precondition forbids once #72
  lands.
- **Kill switch bug (same shape as core's, confirmed live here too).**
  Line 25-28: `case "${SALES_QUALIFICATION_GATE_OFF:-}" in
  ""|0|false|no|off) ;; *) exit 0 ;; esac` — any unrecognized value
  (typo, `"1 "` with trailing space, `"disabled"`) falls into `*)` and
  **disables the gate**. This is the fail-open kill-switch bug generically,
  present in all four sales gates (identical idiom, grep-confirmed).
- **Edit/MultiEdit reconstruction (lines 129-146)**: does **not** honor
  `replace_all` — always `text.replace(old, new, 1)` for Edit, and for
  MultiEdit each edit is also always first-occurrence-only. Matches the
  issue's "Edit/MultiEdit/replace_all 완전 재구성" defect exactly, and
  matches gate-lib.py's already-fixed `_apply_replace`.
- **Deny reasons already go to stderr** (`sys.stderr.write` /
  `echo ... >&2`) — this part already meets the standard.
- **Trap is at top (line 2-3)** — already correct shape, but hand-rolled
  rather than `gate_trap_fail_closed`.

### 3b. `sales-qualification-meddpicc/tests/run-gate-tests.sh`

- **Single-quote payload breakage (issue defect: 작은따옴표 페이로드
  파손).** Line 24: `bash -c "printf '%s' '$actual_payload' | '$GATE'"` —
  `$actual_payload` is interpolated **inside single quotes**. Any test
  fixture whose JSON content contains a literal `'` (e.g. a realistic sales
  note like `"Champion: Bob's team lead"`) terminates the single-quoted
  string early and corrupts the shell command instead of being passed
  through as data. None of the current 6 fixtures happen to contain a `'`,
  which is exactly how this stayed undetected — the harness is broken by
  construction, not by bad luck so far.
- **Missing mandatory cases**: no MultiEdit case, no `replace_all` case, no
  malformed-JSON case, no absolute-path case (only relative `__ROOT__/...`
  paths, which resolve through `CLAUDE_PROJECT_DIR` — never exercises the
  git-toplevel or realpath-outside-root branches), no kill-switch
  *unrecognized-value* case (only the on-spelling `SALES_QUALIFICATION_GATE_OFF=1`
  is tested, never a value that should stay active).

### 3c. `sales-proposal-norm`, `sales-stage-definitions`, `sales-playbook`

Grep across all four `hooks/*-gate.sh` and `tests/run-gate-tests.sh` files
confirms the **same four defect shapes repeat verbatim** in each: identical
kill-switch idiom (`case ... "*") exit 0 ;; esac`), identical `has_any()`
whole-document substring semantic check, identical Edit/MultiEdit
first-occurrence-only reconstruction, and identical single-quoted
`bash -c "... '$actual_payload' ..."` test-harness construction. This means
the fix is one shared pattern applied four times, not four independent
designs.

## 4. README drift (issue defect 4)

Each of the four sales-* plugin `README.md` files documents its gate
script's behavior; spot-checking `sales-qualification-meddpicc/README.md`
against the code above will show the same substring/TBD-adjacency
semantics as currently implemented (not yet upgraded) — the proposal's
phase-2 rewrite must update all four READMEs' behavior descriptions
alongside the code, plus verify no README lists a gate file, kill-switch
name, or plugin path that does not exist (a "유령 파일" pass), across the
top-level `sales/README.md` too.

## Gap line

Field-standard (core gate-lib.sh) already covers: fail-closed trap,
kill-switch semantics, JSON parse safety, path normalization,
Edit/MultiEdit/NotebookEdit reconstruction with `replace_all`. Missing
from the standard by design, and therefore still each rulebook's job:
section/adjacency-aware semantic field-presence checking. The sales
gates today implement none of the standard's mechanical pieces via the
library (all hand-rolled, pre-#72) and also fail at the one piece that
*is* their own job (semantics still substring-based). The proposal below
closes both gaps.
