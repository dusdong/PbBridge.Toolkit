---
name: pbbridge-project-maintenance-router
description: 为 PbBridge 项目开发、V8 delivery session、诊断、Toolkit 升级和发布门禁选择正确 workflow。
---

# 项目维护路由

| 意图 | 使用入口 |
|---|---|
| 修改 `.sr*` 并写回 | `pbbridge-powerbuilder-dev-loop` + `pbbridge-cli`，V8 delivery |
| V8 JSON/session/workspace/退出码问题 | `pbbridge-contract-diagnostics` |
| PowerScript 语法与 PB9 兼容 | `powerbuilder-powerscript` |
| Toolkit/submodule 更新 | `pbbridge-submodule-update` |
| 项目健康与阻断 | `pbbridge-project-health` |
| 发布前门禁 | `pbbridge-release-preflight` |
| PBL 漂移接入 | `pbbridge-pbl-change-intake` / `pbbridge-pbl-drift-remediation` |
| 准入 evidence | `pbbridge-admission-evidence`；运行 `pbbridge project adoption check` |
| Git 发布 | `pbbridge-git-publish` |

路由和审计以 CLI command descriptor、V8 workspace/session、evidence envelope 与 `admissionLevel` 为结构化事实。模板迁移使用 `pbbridge-template-migrate.ps1` 的 AST 迁移与事务回滚。

Toolkit 更新若返回 `toolkit-history-discontinuity`，只能把刚 fetch 的远端分支头作为 `-TargetCommit`，先预检再显式确认 detached 切换；`diverged` 不允许自动丢弃本地提交。项目验收以 project-health `acceptanceSummary` 的 runtime/source/upgrade/release/production 五维为准，禁止把 release clear 表述为 production-ready。

日常交付只路由到：

```powershell
pbbridge delivery close-loop --repo-root <repo> --workspace <id> --object <object-key>=<source-path> --result <v8-preflight.json>
pbbridge delivery continue --from <v8-preflight.json> --apply
```

非当前 Delivery/session 入口必须拒绝，不得重新加入 current router、recommended entrypoint 或正式发布证据。
