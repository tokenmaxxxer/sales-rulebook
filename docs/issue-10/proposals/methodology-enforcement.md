# Issue #10 — Proposal: Enforcement Layer for the Adopted Sales Methodology Norms

Status: **proposal only, phase 1**. No directive text, gate script, plugin
manifest, or test is edited by this document or by this phase. Execution is
phase 2, gated on human Approve per contract v3 s19. Scoped against
`docs/issue-10/reports/sales/current-state-survey.md`,
`docs/issue-10/reports/sales/scout-brief.md`, and the norm source
`docs/issue-1/proposals/methodology-norms.md` (a)/(b)/(d).

## Revision note

An approver left FEEDBACK (not Approve) on this proposal's first cut,
requiring rework per issue #10's "요구 정정" comment: the enforcement layer
must be structured as a **plugin set** — one independent plugin per adopted
methodology, at the same completeness bar as core's `freelunch`/`scout`
plugins (multiple self-contained plugins per rulebook is the norm, not one
bundled plugin) — not a single gate/directive deepened in place. This
revision replaces the prior "one gate, one directive" design below with that
structure. The mechanical content this proposal enforces (MEDDPICC/BANT
fields, stage-definition shape, playbook sections, six-section phase-1
structure) is unchanged from the first cut and from
`docs/issue-1/proposals/methodology-norms.md`; only how it is packaged into
plugins has changed.

## Guiding principle

Every adopted methodology gets its own independent, self-contained plugin —
directive fragment, gate, tests, and (only where the methodology actually
has a repeated multi-step procedure) an agent — registered on its own in
`.claude-plugin/marketplace.json`, exactly as core hosts `freelunch` and
`scout` as separate installable units rather than one "core enforcement"
plugin. The existing `sales` plugin becomes a thin role-shell that composes
the methodology plugins by sourcing their directive fragments and PreToolUse
hooks; it owns role identity and hand-off, not methodology mechanics. Phase-1
proposal-norm enforcement and phase-2 deliverable-norm enforcement are each
expressed as *which plugins compose to form them*, not as separate
freestanding specs — the plugin-composition list below is the design, not an
appendix to it.

## Mandatory plugin list

| # | Plugin (dir) | Methodology owned | Components | Composes into |
|---|---|---|---|---|
| 1 | `sales` (existing, thinned) | role identity: decides/use_when/hand-off; no methodology depth | `hooks/directive.sh` (role-identity fragment only), `hooks/hooks.json` (sources 2–5's hooks), `agents/warrant-hunter.md` (core canon reference, unchanged) | shell that composes 2–5 |
| 2 | `sales-proposal-norm` (new) | phase-1 proposal structure (methodology-norms.md (a)): six required sections in order, evidence-format rule | `hooks/directive.sh` fragment (USE_WHEN facet), `hooks/proposal-norm-gate.sh`, `tests/run-gate-tests.sh` | **the phase-1 (기획서) norm in full** — this plugin alone is that norm |
| 3 | `sales-qualification-meddpicc` (new) | qualification criteria (methodology-norms.md (b) §Qualification): MEDDPICC default / BANT fallback, no silently-omitted field, Economic Buyer + Champion required before advancement | `hooks/directive.sh` fragment (PRODUCES facet, qualification only), `hooks/qualification-gate.sh`, `tests/run-gate-tests.sh` | one of three plugins composing the phase-2 (산출물) norm |
| 4 | `sales-stage-definitions` (new) | stage definitions (methodology-norms.md (b) §Stage definitions): 5–7 stages, ≥2 falsifiable past-tense exit criteria per stage, named next-stage handoff | `hooks/directive.sh` fragment (PRODUCES facet, stages only), `hooks/stage-definitions-gate.sh`, `tests/run-gate-tests.sh` | one of three plugins composing the phase-2 (산출물) norm |
| 5 | `sales-playbook` (new) | sales playbook (methodology-norms.md (b) §Sales playbook): five required sections, marketing hand-off boundary (no inline messaging/positioning copy) | `hooks/directive.sh` fragment (PRODUCES facet, playbook only), `hooks/playbook-gate.sh`, `tests/run-gate-tests.sh` | one of three plugins composing the phase-2 (산출물) norm |

No sixth plugin/agent is added for a repeated-procedure agent: as in the
first cut, the scout pass found methodology-norms.md names no repeated
multi-step procedure beyond the deliverable-shape checks plugins 3–5 already
encode, and no surveyed sibling rulebook adds a role-specific agent for its
own methodology gate. `warrant-hunter.md` remains the only agent reference,
unchanged, inside plugin 1.

## Composition: how the two norms are built from the plugin set

- **기획서(phase-1) norm** = plugin 2 (`sales-proposal-norm`) alone. It is
  not a separate spec restated in prose; the plugin's gate *is* the norm's
  enforcement, and its directive fragment *is* the norm's guidance surface.
  Any future change to the six-section requirement is a change to this one
  plugin, not to a cross-cutting document.
- **산출물(phase-2) norm** = plugins 3 + 4 + 5 composed. Which of the three
  fires on a given write depends on which deliverable path is touched
  (`docs/issue-<n>/reports/sales.md` sections keyed to qualification /
  stages / playbook respectively, per methodology-norms.md (d)'s
  `record-fields` keys) — a role working only on stage definitions in a
  given issue only needs plugins 1+2+4 installed, not all five. The
  `sales` role-shell (plugin 1) is what declares all three as intended
  composition partners in its `hooks.json` and directive, but each remains
  independently installable and independently testable, matching how core
  documents `freelunch`/`scout` as separately-installed plugins rather than
  bundling them.
- Cross-plugin sequencing (Economic Buyer/Champion before stage advancement,
  methodology-norms.md's one named order constraint) lives in plugin 3
  (`sales-qualification-meddpicc`)'s gate, since it resolves within the
  qualification-criteria fields of a single record write and does not
  require plugin 4 to read plugin 3's state — no cross-plugin state file is
  needed for the norms as currently adopted.

## Per-plugin breakdown

### Plugin 1 — `sales` (role-shell, thinned from current skeleton)

**What changes**: `sales/hooks/directive.sh` is reduced to the
`YOU_DECIDE`/`HAND_OFF` role-identity facets only (unchanged content from
today) plus a composition block that sources plugins 2–5's directive
fragments in a fixed order (proposal-norm → qualification → stages →
playbook). `sales/hooks/record-fields-gate.sh` is removed — its
responsibility is redistributed to plugins 2–5's own gates, which is a more
precise split than one file undersizing itself as
`record-fields-gate.sh` while covering three unrelated deliverable shapes
(the same gap the first-cut proposal identified, now fixed by giving each
shape its own plugin instead of its own `if` branch).

**Why**: matches the required structure — the role-shell should compose,
not itself encode, methodology mechanics.

### Plugin 2 — `sales-proposal-norm`

**What changes**: new plugin. `hooks/proposal-norm-gate.sh` targets
`docs/issue-[0-9]+/proposals/.*sales.*\.md`, fail-closed trap-at-top
(`trap __fc EXIT`), resolved-path regex matching against
`CLAUDE_PROJECT_DIR` with git-root fallback — the pattern verified in
`pricing/hooks/methodology-gate.sh` lines 2-3, 46-58 and
`implementation-rulebook/coding/hooks/coding-progress-gate.sh` lines 2-9.
Checks the six required sections from methodology-norms.md (a) by
case-insensitive heading/keyword scan (status, scope, guiding principle,
per-item breakdown, adoption rationale, plugin-reflection plan; this
document's own headings are written to satisfy that scan), assembled into a
single missing-list `deny()`. Kill switch:
`SALES_PROPOSAL_NORM_GATE_OFF=1`.

**Tests**: `tests/run-gate-tests.sh` (disposable-repo, stdin-JSON,
exit-code-assertion shape from `implementation-rulebook/tests/run-gate-tests.sh`)
— allow: all six sections present (this revised document is a fixture
case); deny: adoption-rationale section missing; allow: kill switch set;
allow: foreign path untouched.

### Plugin 3 — `sales-qualification-meddpicc`

**What changes**: new plugin. `hooks/qualification-gate.sh` targets
`docs/issue-[0-9]+/reports/sales\.md`, same fail-closed/resolved-path shape
as plugin 2. Requires `framework_used` present with a MEDDPICC or BANT
*value* (not a bare/placeholder key — the gap the first-cut survey found in
today's `record-fields-gate.sh`); when the record states an opportunity has
advanced past initial qualification (stage-name-list or explicit-phrase
heuristic), requires non-TBD `economic_buyer` and `champion`. Kill switch:
`SALES_QUALIFICATION_GATE_OFF=1`.

**Tests**: allow — complete record (MEDDPICC, Economic Buyer + Champion
named, no advancement claimed); deny — advancement claimed with an empty/TBD
Economic Buyer field; allow — kill switch set.

### Plugin 4 — `sales-stage-definitions`

**What changes**: new plugin. `hooks/stage-definitions-gate.sh`, same
target/fail-closed shape. Requires `stage_count` as an integer in the
surveyed 5–7 range, `exit_criteria_present` per stage, and a lightweight
past-tense heuristic (deny on a stage-name line matching a rep-activity verb
list — "had", "did", "presented", "called" — with no completed-action
phrasing; documented as heuristic, not a full parse, matching this repo
family's accepted keyword/regex precision level). Kill switch:
`SALES_STAGE_DEFINITIONS_GATE_OFF=1`.

**Tests**: allow — stage_count in range with exit_criteria_present per
stage; deny — rep-activity-verb stage name; allow — kill switch set.

### Plugin 5 — `sales-playbook`

**What changes**: new plugin. `hooks/playbook-gate.sh`, same target/
fail-closed shape. Requires all five methodology-norms.md (b) §Sales
playbook sections present by heading keyword (process overview,
qualification framework, ICP/persona, objection-handling, metrics); denies
when messaging-script/positioning-copy content is detected inline rather
than referenced (the marketing hand-off boundary). Kill switch:
`SALES_PLAYBOOK_GATE_OFF=1`.

**Tests**: allow — all five sections present, no inline messaging copy;
deny — inline messaging-script content detected; allow — kill switch set.

## `freelunch` completeness

Two distinct senses of "freelunch" apply here, and this proposal addresses
both:

1. **Completeness bar.** The approver's instruction ("freelunch 수준의
   완성도") sets `freelunch`/`scout` as the reference for what "independent
   plugin" means: each of plugins 2–5 above is self-contained (own
   directive fragment, own gate, own tests, own kill switch, own
   `.claude-plugin/plugin.json`), independently installable, and
   independently testable — not a stub that forwards to a shared
   mechanism the way `sales/hooks/tests/run-stub-check.sh` today only
   wraps core's generic drift check without exercising this role's own
   gate logic. Plugin 1 keeps that stub-wrapper pattern only for
   `warrant-hunter.md`, which is explicitly out of scope (a core canon
   reference, per this issue's constraint) — plugins 2–5 do not use it.
2. **Phase-2 fan-out use.** `freelunch` (core's parallel-work-discipline
   plugin, `freelunch-code-fanout`) is the mechanism phase-2 execution
   should use to build plugins 2–5: each plugin's write set (its own
   directory: `sales-proposal-norm/`, `sales-qualification-meddpicc/`,
   `sales-stage-definitions/`, `sales-playbook/`) is disjoint from the
   others and from plugin 1's thinned `sales/` directory, so the four new
   plugins are a clean fan-out cut with zero file collisions — the
   plugin-per-methodology structure this proposal adopts is what makes
   that fan-out possible in the first place, rather than one shared
   `methodology-gate.sh` that every worker would need to edit
   concurrently. This is noted here as a phase-2 execution consideration;
   no fan-out is performed by this phase-1 document.

## Adoption rationale

- One methodology = one independent plugin, at `freelunch`/`scout`'s
  completeness bar: sourced directly from the approver's "요구 정정" comment
  on issue #10 and the FEEDBACK comment on this PR (both quoted in scope
  above); cross-confirmed by this repo's own `.claude-plugin/marketplace.json`
  precedent of one plugin per role/mechanism rather than a bundle.
- Fail-closed trap-at-top, resolved-path regex matching, full-content
  reconstruction for Edit/MultiEdit, and a single missing-list `deny()`
  inside each plugin's gate: sourced from
  `pricing-rulebook/pricing/hooks/methodology-gate.sh` (lines 2-3, 46-58,
  129-159, 166-218) and cross-confirmed in
  `implementation-rulebook/coding/hooks/coding-progress-gate.sh` (lines
  2-9) — the same shape appearing independently in two sibling rulebooks is
  the scout pass's saturation signal, not a single exemplar's idiosyncrasy;
  unchanged from the first-cut proposal, only relocated per-plugin.
- Record-state sequencing (Economic Buyer/Champion before advancement)
  resolved inside plugin 3 rather than a cross-plugin state file: sourced
  from `coding-progress-gate.sh` (lines 144-167, the `resolved_findings` +
  `loop_state: cleared` pattern) as the precedent for *when* cross-write
  state tracking is warranted; methodology-norms.md's one named order
  constraint resolves within a single record write, so that precedent's
  heavier mechanism is not imported.
- Keyword/regex presence over markdown-structural parsing in every gate:
  sourced from the same `methodology-gate.sh` (its checks are all
  `has_any(...)` substring/keyword tests, no markdown AST) — matches this
  repo family's accepted precision level.
- Gate-test harness shape (disposable git repo, stdin JSON, exit-code
  assertion), one copy per plugin: sourced from
  `implementation-rulebook/tests/run-gate-tests.sh` in full.
- No new agent in any of the five plugins: absence-of-precedent finding —
  neither surveyed sibling rulebook adds a role-specific agent for its own
  methodology gate, and methodology-norms.md names no repeated procedure
  that would need one.

## Plugin-reflection plan (phase 2, gated on Approve)

- `sales/hooks/directive.sh`: thin to role-identity facets + composition
  block, per plugin 1.
- `sales/hooks/record-fields-gate.sh`: delete; responsibility moves to
  plugins 2–5.
- New plugin directories `sales-proposal-norm/`, `sales-qualification-meddpicc/`,
  `sales-stage-definitions/`, `sales-playbook/`, each with
  `.claude-plugin/plugin.json`, `hooks/hooks.json`, its own gate script
  under `hooks/`, and `tests/run-gate-tests.sh`, per plugins 2–5's target
  shapes above.
- `.claude-plugin/marketplace.json`: add four new entries (one per new
  plugin), each with `name`/`source`/`description` naming the single
  methodology it owns, alongside the existing `sales` entry.
- `README.md`: update Install (list all five plugins) and Layout (describe
  the composition, replace the `record-fields-gate.sh` bullet, add one
  bullet per new plugin's gate and tests dir).
- No change to `sales/agents/warrant-hunter.md` (stays a core canon
  reference) and no change to `docs/issue-1/proposals/methodology-norms.md`
  (the norm source is read-only from this issue's perspective).
- Exact regex/keyword lists, the full six-section heading-scan
  implementation per plugin, and the complete gate-test case sets per
  plugin are phase-2 execution detail, confirmed against each actual gate
  script being written rather than fixed in advance here.
