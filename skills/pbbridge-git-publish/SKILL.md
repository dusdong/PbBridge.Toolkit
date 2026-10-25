---
name: pbbridge-git-publish
description: 当用户要求提交、commit、推送、push 主项目或 submodule 变更，处理 PowerBuilder .sr* 修改、toolkit 或 pb-libs 子模块内部提交，以及父仓库 submodule 指针提交时使用。
---

# PbBridge Git Publish

使用本 skill 提交和推送 PbBridge 相关项目变更。核心原则是先识别 Git 边界，再分别处理子模块内部提交、父仓库 submodule 指针提交和普通主仓库源码提交。

## 先识别提交边界

1. 在当前目录运行 `git rev-parse --show-toplevel`，确认当前 Git 仓库根目录。
2. 在父仓库运行 `git status --short --branch` 和 `git submodule status --recursive`，确认是否存在 submodule 指针变化。
3. 若修改位于 submodule 内，进入 submodule 单独检查 `git status --short --branch`、`git diff --stat` 和必要的 `git diff`。
4. 不把子模块内部文件修改和父仓库指针修改混在同一次仓库提交里；先提交并推送子模块，再提交父仓库指针。
5. 子模块或父仓库 push 前必须运行 `scripts/pbbridge-release-check.ps1`；缺失 remote、submodule dirty、未解释 `.pbl` 漂移或 `.pbbridge/workspaces` 入库风险必须先处理。
6. 提交 `.pbl` 前如有漂移，先读取或生成 `.pbbridge/pbl-drift-remediation.json`；`stillBlocking=true` 的 `.pbl` 不应提交。
7. 如果 `.pbl` 来自 PowerBuilder IDE 直接修改，优先运行 `scripts/pbbridge-pbl-change-intake.ps1`，让 remediation、readonly sync 和 release-check 对齐后再判断提交范围。
8. 复杂提交或发布相关提交前，优先读取 `.pbbridge/precommit-summary.json` 和 `.pbbridge/project-health.json`；缺失时建议运行 `scripts/pbbridge-precommit-summary.ps1` 或 `scripts/pbbridge-project-health.ps1` 获得总览。
9. 外部项目接入或升级 Toolkit 后，优先运行 `pbbridge project adoption check --profile standalone|shared-library-self|shared-library-consumer|pb9`；需要长期接入基线时追加 `--write-baseline`，随后用 `pbbridge project drift check` 检查事实漂移。它只读检查 runtime/template/wrapper、shared-library evidence 和 `.pbbridge/workspaces` 风险，不允许静默覆盖本地自定义文件。

## 提交前检查

必须排除：

1. `.pbbridge/workspaces/`
2. 无关 `bin/` 构建产物
3. PowerBuilder IDE 全量编译造成但与本次 `.sr*` 语义修改无关的 `.pbl` 漂移
4. 临时日志、测试缓存和未说明来源的二进制
5. 未 DryRun、未 post-apply review 或未解释来源的 `.pbl/.pbd/.exe`
6. 只有 `pbl-lfs-filter-mismatch` 但没有 import/post-apply/shared-library/manual 解释链的 `.pbl`
7. 默认排除 `.pbbridge/workspaces/`、`.pbbridge/cache/`、`.pbbridge/diagnostics-bundle*/`、`.pbbridge/pbl-change-intake.json`、`.pbbridge/release-check.json`、`.pbbridge/project-health.json`、`.pbbridge/precommit-summary.json` 和其他根级本机 workflow state JSON，除非项目有明确发布证据归档策略或 `.pbbridge/evidence-policy.json` 要求提交
8. 模板迁移报告中的 `manual-snippet-merge` 和 `expected-project-customization` 不应被当成可自动覆盖许可；`project-configuration` 代表受管 wrapper 的项目默认参数差异，应作为项目配置保留。若条目仍是 `managed-template / overwrite-with-backup` 且包含 `projectConfigurationDiffs[]`，提交前必须确认覆盖或合并后保留这些参数；提交前只保留已人工合并的 `AGENTS.md`、`.gitignore`、`.gitattributes` 或 `move-pb-build-output.ps1`

必须确认：

1. `.sr*` 修改范围与用户任务一致。
2. 已按任务风险运行必要的 `verify / diff / report` 或说明未运行原因。
3. 写回 `.pbl` 的任务已经先完成 DryRun；Apply 必须有用户确认。
4. 如果要提交 `*.pbl/*.pbd/*.exe`，确认项目策略和 Git LFS 规则允许。
5. 用户问“能否发版”或“发布前检查”时，先转 `pbbridge-release-preflight`，不要只凭 Git 状态判断可发布。
6. `pbl-drift-remediation.json` 中每个本次 `.pbl` 变更的 `stillBlocking=false`，并且证据路径随提交或发布记录保留。
7. release-check 或 intake 的 `checks[]/nextActions[]` 提示 `.pbl` 证据未刷新时，不能把“没有 `.sr*` diff”解释成“PowerBuilder IDE 没有业务源码变更”；应先运行 `pbbridge pbl change-intake` 或 readonly sync，必要时用 `-IncrementalRefresh -RefreshLibrary/-RefreshObjectKey` 定向刷新，或说明只提交二进制证据的理由。
8. release-check/project-health 的 `decision.currentChangeBlocked`、`decision.historicalBlocked` 和 `decision.toolkitConfigBlocked` 已分层时，提交说明必须区分“本次变更阻断”和“历史存量阻断”。
9. `pbl-change-intake.json` 只作为本机 intake 摘要，不随普通提交保留；需要追溯完整输出时引用其 `logDirectory`。
10. 版本发布、打 tag 或推送 release 分支前，必须运行 `scripts/build-release-engineering.ps1 -SkipAutonomousGate -RequireToolkitAlignment` 并检查 `artifacts/release/<version>/checks/release-engineering-summary.json`。
11. release/tag guard 显示目标 tag 已存在但不指向当前 HEAD 时，不得继续打 tag 或推送；除非用户明确要求并理解风险，否则不要使用允许移动 tag 的参数。
12. release engineering summary 的 `releaseAssetHandoff.status=blocked` 必须阻断发布；`releaseProvenance` 必须记录 tagCommit、Toolkit、CLI、release manifest、SHA256SUMS、runtime contract 和 releaseArtifacts；`releaseNotesSummary.path` 是人工发布页摘要，应随发布记录交接。

## 推荐发布顺序

1. 子模块内部有真实源码修改时，在子模块内提交并推送。
2. 回到父仓库，确认 submodule 指针已更新。
3. 父仓库提交 submodule 指针、项目脚本、`.sr*` 或配置变更。
4. push 前运行 release-check，并再次展示将推送的分支、远端和提交摘要。
5. push 后报告远端分支、提交 hash 和仍需人工验收的事项。
6. 复杂任务按 `skills/_shared/handoff-template.md` 补齐 verify、import、post-apply review、release-check、IDE 和 Git 状态。
7. 发布 tag 前先读取 release engineering summary；只有 `status=success|clear`、tag guard 未阻断且 release asset handoff 未阻断时，才进入创建和推送 tag。

## 提交信息

提交信息使用简洁中文或项目既有风格，优先描述业务或流程结果：

```text
更新 PbBridge.Toolkit workflow skills
```

```text
刷新 pb-libs 子模块并更新 PbBridge baseline
```

避免使用只描述工具动作的提交信息，例如“fix files”或“codex changes”。

## 失败处理

1. 工作区有用户未说明的修改时，先报告并停止提交。
2. 远端 push 被拒绝时，先 fetch 并说明分叉情况，不自动 rebase 或 merge。
3. 子模块 detached HEAD 时，先确认目标分支，不直接提交到不可追踪状态。
4. 任何破坏性操作，例如 reset、checkout 覆盖、删除未跟踪文件，都必须得到明确授权。

## 权威资料

- `CODEX-START.md`：Git 管理边界和 PowerBuilder 二进制管理建议。
- `skills/pbbridge-cli/SKILL.md`：修改 `.sr*` 后的 verify、diff、report、import 要求。
- `docs/getting-started/外部PowerBuilder项目接入Codex.md`：外部项目接入和协作边界。
