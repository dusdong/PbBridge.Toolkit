# PbBridge 本机证据片段

- `.pbbridge/local/` 是本机运行证据目录，包含 results、diagnostics-bundle、staging、scratch-preflight 和 re-export-review。
- `.pbbridge/evidence-supersession/` 是 Apply 后写出的本机 evidence sidecar 目录，用于说明旧 failed/blocked/rolled-back 证据已被当前成功写回取代。
- `.pbbridge/local/` 与 `.pbbridge/evidence-supersession/` 默认不提交；正式 workspace state 仍位于 `.pbbridge/workspaces/`，只有项目有明确审计归档策略时才人工提交 supersession sidecar。
- wrapper 只透传 CLI JSON 与退出码，不在 PowerShell 中重新判断业务规则。
