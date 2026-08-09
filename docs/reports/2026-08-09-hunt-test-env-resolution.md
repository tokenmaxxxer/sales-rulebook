---
proposal: docs/issue-25/proposals/2026-08-09-test-env-resolution.md
---

# Hunt record — test-env-resolution

## before-landing — stance 4: assume the write set cannot carry this work — find the path the build will need that the proposal does not list

Verdict: FINDING — the new pre-flight resolver in `sales/hooks/tests/run-stub-check.sh` ignores the documented `CORE_PLUGIN_ROOT` override, so setting it (as `docs/handbooks/stub-check.md` explicitly instructs, and as issue-5/issue-19 verification runs did) now SKIPs (exit 75) instead of running the check — the handbook (or the resolver's candidate list) is a file the write set needed to touch but doesn't.
Kind: composition
Seed: git diff of sales/hooks/tests/run-stub-check.sh + 4x */tests/run-gate-tests.sh + new tests/lib/test_env_resolve.py
cap_seconds: 120
tier: default
diff_stat_lines: 43 insertions(+), 1 deletion(-) across 5 files (per git diff --stat)
started_at: 2026-08-09T09:54:34+09:00
ended_at: 2026-08-09T10:02:00+09:00

### Reproduce
```
mkdir -p <SCRATCH>/fakecore/hooks/lib <SCRATCH>/fakecore/hooks/tests
cat > <SCRATCH>/fakecore/hooks/tests/stub-check.sh <<'SCRIPT'
#!/usr/bin/env bash
echo "stub-check ran with arg: $1"
SCRIPT
cat > <SCRATCH>/fakecore/hooks/lib/gate-lib.sh <<'SCRIPT'
echo lib-loaded
SCRIPT
chmod +x <SCRATCH>/fakecore/hooks/tests/stub-check.sh

unset CLAUDE_PLUGIN_ROOT_CORE
export CORE_PLUGIN_ROOT=<SCRATCH>/fakecore
bash sales/hooks/tests/run-stub-check.sh
echo "EXIT_CODE=$?"
```

### Observed
```
SKIP: core plugin unreachable — unverifiable outside spawn env
EXIT_CODE=75
```
The check never runs even though `CORE_PLUGIN_ROOT` correctly points at a
core checkout containing `hooks/lib/gate-lib.sh` and
`hooks/tests/stub-check.sh` — the documented, on-record override mechanism
from `docs/handbooks/stub-check.md` ("If your install doesn't place core
there... override with `CORE_PLUGIN_ROOT`") is silently short-circuited by
the new pre-flight, which only consults `CLAUDE_PLUGIN_ROOT_CORE` and its
own hardcoded sibling-path candidates (see `resolve_core()` in
`tests/lib/test_env_resolve.py`), never the caller's `CORE_PLUGIN_ROOT`.

### Expected
Setting `CORE_PLUGIN_ROOT` per the handbook should make the script run the
real stub-check (exit 0/1/2 from the actual check), not SKIP with exit 75 —
same as it did before this change (`"${CORE_PLUGIN_ROOT:-...}"` was
evaluated directly, with no pre-flight in front of it).
