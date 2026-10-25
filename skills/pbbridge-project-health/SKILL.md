---
name: pbbridge-project-health
description: 当用户询问外部 PowerBuilder 项目当前是否可继续 Apply、提交、推送或发布，或需要统一查看 verify、release-check、source-hygiene、shared-library gate、模板迁移、Git/submodule 和 PBL 漂移状态时使用。
---

使用本 skill 做项目健康总览。目标是先读 `.pbbridge/project-health.json`，再按缺失项补读 release-check、verify、source-hygiene、共享库 gate、模板迁移和 Git 状态，给出“可继续 / 需刷新证据 / 阻断”的明确结论。

## 入口

优先运行或读取 CLI 原生命令；外部项目旧脚本是同名入口包装层，会转调 Toolkit CLI runtime 并保存 stdout/stderr 日志。找不到 CLI runtime 时脚本直接失败并提示升级；不再提供旧 PowerShell 业务引擎。

```powershell
PbBridge.Cli.exe project health
pbbridge project health --workspace-name <name>
```

包装脚本入口：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-project-health.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-project-health.ps1 -Compact
```

同仓多 PBW 项目必须使用当前 PBW 对应的命名工作区：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-project-health.ps1 -WorkspaceName kuaican
```

如果用户明确要求刷新只读证据，优先使用：

```powershell
pbbridge workspace readonly-sync
pbbridge project health --refresh-readonly-evidence
```

包装脚本仍可使用：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-project-health.ps1 -RefreshReadonlyEvidence
```

2.11.0 起 `pbbridge workspace readonly-sync` 会执行 export、verify、report、source-hygiene 和 baseline refresh；这仍只是只读证据刷新，不代表可以 Apply、提交、推送或跳过 IDE 编译验收。

## 判断顺序

1. 读取 `.pbbridge/project-health.json`；非 default 工作区读取 `.pbbridge/workspaces/<WorkspaceName>/state/project-health.json` 的 `status`、`decision`、`checks[]` 和 `nextActions[]`。
2. 如果 health 缺失或 stale，建议先运行 `scripts/pbbridge-project-health.ps1`；只需要查看短摘要时追加 `-Compact`，完整事实仍读取 `.pbbridge/project-health.json` 或工作区 state JSON。
3. 如果 health blocked，先看 `decision.currentChangeBlocked`、`decision.historicalBlocked`、`decision.toolkitConfigBlocked` 和 `decision.canCommitCurrentChange`，再按 `checks[].issues[]` 分类处理。
4. 如果 health warning，说明可继续的前提和仍需人工确认的证据。
5. 如果 health clear，仍要提醒 PowerBuilder IDE Full Build 和运行验收不由 PbBridge 代替。

## blocked 清理顺序

遇到 `status=blocked` 或脚本 exit 10 时，先判断它是健康结果 blocked，不是脚本异常；exit 1 只表示真实执行失败。除非 stdout/stderr 明确显示脚本崩溃，否则按以下顺序清理：

1. Git/submodule：先看 `git status --short --branch` 和 `git submodule status --recursive`，整理父仓、`pb-libs`、`pb-langchao` 等共享库的 staged/unstaged 差异。
2. Verify blocker：`PBV076 managed-blocker` 必须修 `.srf` 结构污染；可运行 `pbbridge suggest-fixes <artifactsRoot> --code PBV076` 查看 `categories[]` 和 `repairPlan[]`，但不能用 `ForceApply` 绕过。
3. 共享库边界：缺 `.pbbridge/shared-libraries.json` 时，优先运行 `scripts/pbbridge-init-shared-libraries.ps1` 生成草案，再按项目事实确认 `evidenceMode=self|consumer` 和共享库路径，最后运行 shared-library gate。
4. 只读证据：缺 `source-hygiene.json`、`verify.json` 或 `report.md` 先运行 `pbbridge workspace readonly-sync`；缺 `release-check.json` 再运行 `pbbridge release check --allow-blocked-result`，同名脚本仅作为包装入口。
5. `.pbl` drift：存在未解释 `.pbl` 变化时，运行 `scripts/pbbridge-pbl-drift-remediation.ps1`，并补 import/post-apply/shared-library/manual evidence 或二进制基线策略。
6. IDE 验收：最后明确 PowerBuilder IDE Regenerate / Full Build / 运行验收是否完成。

## 边界

1. 本 skill 只做只读健康判断，不提交、不推送、不更新 submodule 指针。
2. 不自动修改 `.sr*`、`.pbl`、模板文件或 `.pbbridge/workspaces`。
3. `.pbl` 漂移必须由 import/post-apply、shared-library gate 或后续 drift remediation 证据解释，不能用 source-hygiene 单独解释。
4. release-check 仍是发布门禁；project-health 是导航和聚合入口。
5. 多 PBW 项目中不得用另一个工作区的 manifest、verify 或 release-check 解释当前 PBW。
6. `.pbbridge/evidence-policy.json` 只提供提交建议；即使 `recommendedGitAction=commit`，本 skill 也不自动 stage 或 commit。

## 输出要求

结束时至少说明：

1. 总体状态：`clear`、`warning`、`stale` 或 `blocked`。
2. 决策分层：本次变更阻断、历史存量阻断、Toolkit/配置阻断，以及本次变更是否可提交。
3. 阻断或 warning 的 check 名称和 issue code。
4. 建议下一步命令。
5. 是否仍需 PowerBuilder IDE 编译和运行验收。
