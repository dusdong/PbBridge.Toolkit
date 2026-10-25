---
name: pbbridge-pbl-change-intake
description: 当用户说明 PowerBuilder IDE 直接修改了 .pbl、PBL 有变化但 src/.sr* 没有 diff、srDiff=false 与预期不符、需要反导出刷新文本投影或运行 pbl change-intake 时使用。
---

# PbBridge PBL Change Intake

使用本 skill 处理“PowerBuilder IDE 已经直接改过 `.pbl`，需要重新投影到 `.sr*` 文本事实源”的场景。2.11.0 起优先使用 `pbbridge pbl change-intake`；PowerShell 脚本只是同名入口包装层，不再提供旧超时开关或子脚本编排引擎。

## 快速路径

先判断这次需要的是完整门禁，还是只想快速刷新命中 PBL：

0. **单对象重建优先 object 意图入口**：如果用户只是要找一个对象、导出一个 `.srd/.srw/.sru`，或修复被删掉的单个源码文件，优先使用 `pbbridge object find/export/repair`。这些命令不依赖旧 manifest 作为显式 PBL 导出的前置条件，默认不删除、不覆盖、不写回 PBL；compact stdout 顶层提供 `cacheStatus` 和 `totalElapsedMs`，完整 JSON 的 `performanceSummary` 说明对象定位、PBL 导出和结果写入等阶段耗时。`object find` 会复用 `.pbbridge/cache/object-intent-index.current.json`，精确对象查询优先轻拓扑 `shardedIndexLookup` / `lookupShardHit`，模糊查询才 `linearFallback`，默认按 PBL/source root/源码父目录祖先链拓扑校验缓存，源码正文变化不触发定位索引重建；冷缓存并发执行时只有一个进程 rebuild，其余进程等待后复用已原子发布的 current index，`cacheStatus` 为 `memory-hit`、`disk-hit`、`rebuilt` 或 `missing-root`。
1. **默认 full intake**：当你需要 `pbl drift-remediation`、`readonly-sync`、`release-check` 一整条证据链，或当前要做发布前检查、整仓验收、范围未知排查时，继续使用默认 `pbbridge pbl change-intake`。
2. **projection-only 轻量模式**：当你已经确认 PowerBuilder IDE 的修改只影响一个或少量 PBL / 对象，当前目标只是把命中 PBL 的 `.sr*` 文本投影与 manifest 快速刷新出来时，优先使用 `--projection-only`。
3. **轻量模式的硬约束**：`projection-only` 必须同时传 `--refresh-library` 或 `--refresh-object-key`；它不会替你跑 drift-remediation、verify、report、source-hygiene、baseline refresh、release-check 或仓库级 gate。
4. **一句话记忆**：需要完整证据链就走 full intake；只想把已知命中 PBL 的文本投影快速刷出来，就走 `projection-only`。

## 触发判断

优先使用本 skill：

1. 用户说“我刚在 PowerBuilder 里改了 `.pbl` / application / function / window”。
2. Git 有 `.pbl` diff，但 `src/**/*.sr*` 没有 diff，用户预期应该有业务源码变化。
3. release-check、drift remediation 或 precommit-summary 显示 `.pbl` 漂移仍需要刷新只读证据。
4. 用户问“为什么 SourceTree 看不到 `.sr*` 变化”“是不是没导出”“需要反导出确认”。

如果用户只问 `.pbl` 漂移分类、LFS filter mismatch、metadata-only drift 或修复计划，使用 `pbbridge-pbl-drift-remediation`。如果用户已经确认 `.pbl` 变化来自 PowerBuilder 编译选项、project options 或经评审 metadata-only 变化，使用 `pbbridge-pbl-binary-baseline` 登记可提交策略证据。

## 必读证据

1. `git status --short --branch`
2. `.pbbridge/pbl-change-intake.json`
3. `.pbbridge/pbl-drift-remediation.json`
4. `.pbbridge/release-check.json`
5. `.pbbridge/workspaces/default/artifacts/pbbridge/manifest.json`
6. `.pbbridge/workspaces/default/artifacts/pbbridge/verify.json`
7. 当前 `.pbl` 对应的 `src/<normalized-pbl-name>/**/*.sr*`

非 default 工作区应读取 `.pbbridge/workspaces/<WorkspaceName>/state/` 下的 intake、release-check 和 remediation 结果，以及 `.pbbridge/workspaces/<WorkspaceName>/artifacts/pbbridge/` 下的 manifest、verify、report。

## 标准命令

优先运行 CLI：

```powershell
pbbridge object find d_yl_bill_ylrkd_master --project-root .
pbbridge object export erp_ylgl.pbl:datawindow:d_yl_bill_ylrkd_master --out src/erp_ylgl/datawindow/d_yl_bill_ylrkd_master.srd --project-root .
pbbridge object repair erp_ylgl.pbl:datawindow:d_yl_bill_ylrkd_master --out src/erp_ylgl/datawindow/d_yl_bill_ylrkd_master.srd --project-root .
```

如果需要完整 intake，再运行：

```powershell
pbbridge pbl change-intake --project-root . --workspace-path .
```

如果只需要刷新命中 PBL 的文本投影，可改用 `projection-only` 轻量模式，但必须同时传刷新目标：

```powershell
pbbridge pbl change-intake --project-root . --workspace-path . --projection-only --refresh-library app_main.pbl
pbbridge pbl change-intake --project-root . --workspace-path . --projection-only --refresh-object-key app_main.pbl:window:w_main
```

如果用户关注“为什么慢”或要求真实运行效率证据，运行只读 benchmark，不用 mock 单测耗时代替结论：

benchmark 的用途是比较同一 runner class、dataset、workload 与 measurement semantics 下的总耗时，并用 Delivery canonical phase 定位瓶颈；phase 指标只用于诊断。medium/large 必须覆盖 no-change、same-PBL 32 对象和同 workspace multi-PBL，且 medium/large `toolkit-upgrade-check` 总耗时预算分别为 15,000ms/45,000ms。runner 或 workload identity 不完整时不得计算相对回归。

```powershell
pbbridge performance dataset-generate --profile medium --repo-root .
pbbridge performance benchmark --profile medium --cache-mode both --project-root <dataset-root> --workspace ws01 --dataset-manifest <dataset-root>/dataset-manifest.json --comparison-baseline <schema-v2-baseline.json> --redact-paths
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-performance-benchmark.ps1 -Profile real -CacheMode both -WorkspaceName canyin -DatasetManifest <real-dataset-manifest.json> -RedactPaths
```

外部项目仍可运行同名脚本，脚本只转调 Toolkit CLI runtime：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-pbl-change-intake.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-pbl-change-intake.ps1 -Compact
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-pbl-change-intake.ps1 -ProjectionOnly -RefreshLibrary app_main.pbl
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-pbl-change-intake.ps1 -Help
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-pbl-change-intake.ps1 -CliHelp
```

同一仓库存在多个 PBW 时，使用命名工作区并直接传 PBW：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-pbl-change-intake.ps1 -WorkspaceName kuaican -WorkspacePath .\KuaiCan.pbw
```

默认 full intake 由 CLI/Core 按顺序执行 `pbl drift-remediation`、`workspace readonly-sync`、`release check`，输出单个 `pbbridge-v4-pbl-change-intake` JSON，固定使用 `schemaVersion=4`。`3.12.0` 起也可用 `--projection-only` / wrapper `-ProjectionOnly` 只刷新命中 PBL 的文本投影与 manifest；该模式必须同时指定 `--refresh-library` 或 `--refresh-object-key`，并会跳过 drift-remediation、verify、report、source-hygiene、baseline refresh、release-check 与仓库级 gate。3.8.0 起 stdout 默认只输出 `pbbridge-v3-compact-summary`，完整 facts 读取 `.pbbridge/pbl-change-intake.json`、指定 `--result` 文件或摘要里的 `resultJsonPath`；`--compact` 和 wrapper `-Compact` 仅作为兼容参数保留。

所有受管 wrapper 帮助入口固定使用 `-Help` 与 `-CliHelp`。`-Help` 不要求业务必填参数；CLI-backed wrapper 的 `-CliHelp` 直接转发 CLI help，不创建 `logs/*-help` 目录。不要用 `-?` 判断 wrapper 是否可用，因为它可能触发 PowerShell 参数解析差异或实际执行路径。

## 结果判断

1. 以 JSON 的 `status`、`stage`、`steps[]`、`checks[]`、`evidence[]`、`artifacts[]`、`nextActions[]` 为准。
2. 轻量 `pbbridge object ...` 结果可先查看 compact 顶层 `totalElapsedMs` 与 `cacheStatus`；需要完整诊断时再读取 `performanceSummary.totalElapsedMs`、`performanceSummary.cacheStatus` 和 `performanceSummary.stages[]`，确认慢点来自对象定位、持久索引缓存、临时 PBL 导出还是语义 inspect。`object diff --semantic` 默认只写最终 diff JSON；需要左右 inspect JSON 时显式运行 `pbbridge datawindow inspect`。
3. `pbbridge-runtime-benchmark` schemaVersion 2 结果额外查看 `productVersion`、`profile`、`cacheMode`、`dataset.contentHash`、`baseline`、`budgetEvaluation`、`reasonCodes[]`、计数器可用性和 skipped 场景；schemaVersion 1 必须重建。
4. `projectionOnly=true` 时，额外查看 `skippedGlobalChecks`、`requestedLibraries`、`refreshedLibraries`、`changedSourceFiles`、`deletedSourceFiles` 与 `libraryResults[]`，确认是否只刷新了预期 PBL。
5. `status=failed`：先看失败 `stage` 和 `checks[].issues[]`。
6. `status=blocked`：不能提交；`AllowBlockedResult` 只保留 JSON，不改变 blocked 语义，先处理 `nextActions[]`。
7. intake 后有 `.sr*` 业务 diff：按 `.sr*` 文本事实源审查业务变化。
8. intake 后仍没有 `.sr*` 业务 diff，且用户确认是编译选项或 project options 变化：转 `pbbridge-pbl-binary-baseline`。
9. verify 仍有 blocker：转 `pbbridge-verify-triage` 分诊。

## 模板清债

外部项目模板的 `template-manifest.json` 将入口分为 `recommendedEntrypoints[]`、`expertEntrypoints[]` 和 `deprecatedEntrypoints[]`。遇到 wrapper 损坏或项目模板漂移时，先读取这三个清单：推荐入口用于日常只读和轻量任务，专家入口用于导入/写回等高风险工作流，废弃入口必须给用户替换建议。

## 安全边界

1. 不直接编辑 `.pbl`。
2. 不把 remediation 的“漂移已解释”写成“`.sr*` 已刷新”。
3. 不把 release-check 当成会自动导出的命令；刷新由 intake 内部 readonly-sync 阶段完成。
4. 不提交 `.pbbridge/workspaces/`、`.pbbridge/cache/`、`.pbbridge/diagnostics-bundle*/`、`.pbbridge/pbl-change-intake.json`、`.pbbridge/release-check.json`、`.pbbridge/project-health.json` 或其他根级本机 workflow state JSON，除非项目有明确归档策略。
5. 提交 `.pbl` 时可保留 `.pbbridge/pbl-drift-remediation.json` 作为解释证据。

## 输出要求

结束时说明：

1. intake 是否已运行，以及 `status`、`stage`、`steps[]` 摘要。
2. `.pbbridge/pbl-change-intake.json` 的 `workspaceModel`、`summaryText`、`checks[]`、`nextActions[]`，以及 `projectionOnly` / `skippedGlobalChecks` / `libraryResults[]`（若存在）。
3. 新出现或仍缺失的 `.sr*` diff。
4. 仅行尾/空白变化是否存在。
5. 剩余 verify/release-check 阻断与下一条命令。
6. 如果项目路径或日志包含中文，确认 wrapper 日志目录下 stdout/stderr 可读。
