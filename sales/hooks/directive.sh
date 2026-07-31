#!/usr/bin/env bash
# SessionStart: sales's role directive. Kill switch: export SALES_CYCLE_OFF=1
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"

YOU_DECIDE="YOU DECIDE: 리드/기회를 어떻게 진행시킬지"
USE_WHEN="USE WHEN: 영업 프로세스 설계가 걸릴 때"
PRODUCES="PRODUCES: sales playbook (process overview + qualification framework + ICP/persona + objection/competitive notes + metrics sections), stage definitions (5-7 stages, entry/exit criteria in past tense, >=2 falsifiable exit criteria each), qualification criteria (MEDDPICC default, BANT fallback for short-cycle/simple deals)"
HAND_OFF="HAND-OFF: 메시지/포지셔닝 자체는 → marketing"
core_role_directive "$YOU_DECIDE" "$USE_WHEN" "$PRODUCES" "$HAND_OFF"
