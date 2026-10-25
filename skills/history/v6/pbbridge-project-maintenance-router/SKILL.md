---
name: pbbridge-project-maintenance-router
description: 为 PbBridge 项目开发、V6 delivery、诊断、Toolkit 升级和发布门禁选择正确 workflow。
---

# 项目维护路由

| 意图 | 使用入口 |
|---|---|
| 修改 `.sr*` 并写回 | `pbbridge-powerbuilder-dev-loop` + `pbbridge-cli`，V6 delivery |
| V6 JSON/schema/退出码问题 | `pbbridge-contract-diagnostics` |
| PowerScript 语法与 PB9 兼容 | `powerbuilder-powerscript` |
| Toolkit/submodule 更新 | `pbbridge-submodule-update` |
| 项目健康与阻断 | `pbbridge-project-health` |
| 发布前门禁 | `pbbridge-release-preflight` |
| PBL 漂移接入 | `pbbridge-pbl-change-intake` / `pbbridge-pbl-drift-remediation` |
| 准入 evidence | `pbbridge-admission-evidence`；运行 `pbbridge project adoption check` 与 `pbbridge diagnostics summary` |
| Git 发布 | `pbbridge-git-publish` |

路由和审计以 CLI command descriptor、evidence envelope 与 `admissionLevel` 为结构化事实。模板迁移遇到项目自定义时保留 `manual-snippet-merge`、`expected-project-customization`、`canAutoApply` 分类；`move-pb-build-output` 仍按项目配置审阅。

日常交付只路由到：

```powershell
pbbridge delivery close-loop --object <object-key>=<source-path>
pbbridge delivery close-loop --object <object-key>=<source-path> --apply --preflight-result <v6-dryrun.json>
pbbridge delivery close-loop --object <object-key>=<source-path> --apply-if-eligible --policy <policy.json>
```

V4/V5 文档与命令结果只能用于历史排障，不得进入当前 delivery 事实计算。旧输入被拒绝时，升级 Toolkit 并重新运行 V6 DryRun。
