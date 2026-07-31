#!/usr/bin/env bash
# SessionStart: sales's role directive. This role-shell composes the
# methodology-plugin directive fragments (proposal-norm, qualification,
# stage-definitions, playbook) rather than encoding their methodology depth
# itself — see docs/issue-10/proposals/methodology-enforcement.md. Kill
# switch: export SALES_CYCLE_OFF=1
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Composition block: source each methodology plugin's fragment, in the fixed
# order proposal-norm -> qualification -> stages -> playbook. Each plugin
# remains independently installable; a missing sibling plugin just leaves
# its fragment variable unset (empty PRODUCES addendum), never fails closed
# here since the role-identity directive itself must still print.
for frag in \
  "$HERE/../../sales-proposal-norm/hooks/directive.sh" \
  "$HERE/../../sales-qualification-meddpicc/hooks/directive.sh" \
  "$HERE/../../sales-stage-definitions/hooks/directive.sh" \
  "$HERE/../../sales-playbook/hooks/directive.sh"
do
  [ -f "$frag" ] && . "$frag" 2>/dev/null
done

YOU_DECIDE="YOU DECIDE: 리드/기회를 어떻게 진행시킬지"
USE_WHEN="USE WHEN: 영업 프로세스 설계가 걸릴 때. ${SALES_PROPOSAL_NORM_FRAGMENT:-}"
PRODUCES="PRODUCES: ${SALES_QUALIFICATION_FRAGMENT:-} ${SALES_STAGE_DEFINITIONS_FRAGMENT:-} ${SALES_PLAYBOOK_FRAGMENT:-}"
HAND_OFF="HAND-OFF: 메시지/포지셔닝 자체는 → marketing"
core_role_directive "$YOU_DECIDE" "$USE_WHEN" "$PRODUCES" "$HAND_OFF"
