# sales warrant-hunter

This role has no local warrant-hunter agent. Background hunting is core's
`warrant` plugin (`tokenmaxxxer-core` marketplace, core issue #63): one
approval gate up front, then uninterrupted execution inside a frozen write
set, with a diff-size-proportional hunt dispatched at proposal and landing.

Role-specific inputs the core agent consumes for this role:
- decision boundary: 리드/기회를 어떻게 진행시킬지 (see README.md "decides")
- hand-off: 메시지/포지셔닝 자체는 → marketing (see README.md "hand-off")
