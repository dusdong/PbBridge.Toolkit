---
name: pbbridge-release-preflight
description: 当用户询问 PbBridge 外部项目能否发布、发布前检查、release-check 结果、PBL/PBD/EXE 漂移、source-hygiene、submodule 指针、readonly sync 证据、verify 阻断或 IDE Full Build 验收是否齐备时使用。
---

# PbBridge Release Preflight

使用本 skill 做发布前质量闸。它只聚合和审查现有证据；不要把它当成提交、推送或打标签入口。需要 Git 操作时转交 `pbbridge-git-publish`。如果项目已提供 `.pbbridge/project-health.json`，先读取该文件作为总览，再回到 release-check 作为正式发布门禁。优先使用 `pbbridge release check`；`scripts/pbbridge-release-check.ps1` 是外部项目同名入口包装层，会转调 Toolkit CLI runtime 并保存 stdout/stderr 日志。找不到 CLI runtime 时脚本直接失败并提示升级；不再提供旧 PowerShell 业务引擎。

`pbbridge-project-health.ps1` 返回 exit 10 且 `.pbbridge/project-health.json` 显示 `status=blocked` 时，按健康检查阻断处理，不要先判断为脚本异常。exit 1 只表示真实执行失败；只有 stdout/stderr 明确显示脚本崩溃、JSON 无法生成或 PowerShell 运行错误时，才按脚本失败处理。

## 必要证据

发布前至少读取：

1. `.pbbridge/workspaces/default/artifacts/pbbridge/verify.json`
2. `.pbbridge/workspaces/default/artifacts/pbbridge/source-hygiene.json`
3. `.pbbridge/release-check.json`
4. `.pbbridge/project-health.json`
5. `.pbbridge/pbl-drift-remediation.json`
6. `.pbbridge/precommit-summary.json` 或 `scripts/pbbridge-precommit-summary.ps1` stdout 摘要
7. `scripts/pbbridge-release-check.ps1` stdout 摘要或 JSON 输出
8. `git status --short --branch` 与 `git submodule status --recursive`
9. 共享库项目的 `.pbbridge/shared-library-writeback-check*.json`
10. 如存在支持矩阵候选评估，读取 `artifacts/ci/pbspy-x86-admission/validation.json` 或 `.pbbridge/admission/validation.json`
11. 发布仓库自身进入版本发布流程时，读取 `artifacts/release/<version>/checks/release-engineering-summary.json`，重点检查 `tagGuard`、`releaseAssetHandoff`、`releaseProvenance`、`releaseNotesSummary`、`status`、`checks[]` 和 `nextActions[]`
12. 如果存在 `.pbbridge/diagnostics-summary.json`，优先读取 `conclusions[]` 辅助判断能否继续修改、DryRun、Apply、提交或发布；但正式发布判断仍以 release-check 与 release engineering summary 为准。
13. 如果需要交接给 CI、SharpIDE 只读层、外部 agent 或人工发布页，读取 `pbbridge diagnostics bundle create` 生成的 `bundleManifest`、`facts[]`、`gitSummary` 和 `sha256[]`，并用 `pbbridge diagnostics bundle verify` 校验完整性；bundle 只是证据索引，不替代 release-check 或 IDE 验收。
14. 进入 3.5.0 或后续发布流程时，运行主仓 `scripts/test-doc-contract-hygiene.ps1 -RequireReleaseEngineeringSummary` 或对应 Pester 用例，确认当前文档、OpenSpec specs、Toolkit docs/skills/templates、golden JSON、release engineering summary 和 `docs/pb9-ai-bridge` 历史入口没有旧 schemaName、错误 blocked 退出码表述、发布状态回退或职责边界漂移。
15. 3.5.0 起，外部项目长期生产接入应读取 `.pbbridge/adoption-baseline.json` 或 `pbbridge project adoption check --write-baseline` 输出，确认 CLI/Toolkit/template/wrapper、manifest facts、source layout、shared-library role/evidence 和 workspace model summary 有可审计基线。
16. 3.5.0 起，发布前或写回前应读取 `pbbridge project drift check` 输出；`driftStatus=blocked` 或 shared-library role/evidence 冲突必须阻断，`driftStatus=warning` 必须列为发布剩余风险或人工复核项。
17. 3.5.0 起，准备 DryRun/Apply/Writeback 前应读取 `pbbridge writeback readiness check` 输出；`readinessStatus=blocked`、`blockedStages[]` 非空、`failureCategory` 非 `none`，或 `rollbackPlan` 缺失关键事实时，不得宣称已具备受控写回条件。
18. 进入 3.6.0 质量收口或后续发布流程时，确认 CLI command descriptor、schema summary/example factory、workflow-specific validator、evidence envelope 说明、Toolkit 文件化同步和 release engineering helper 拆分均有测试或 lint 覆盖。

非 default 工作区应读取 `.pbbridge/workspaces/<WorkspaceName>/state/release-check.json`、`.pbbridge/workspaces/<WorkspaceName>/state/project-health.json` 和对应 artifacts 下的 verify/source-hygiene。不要用 `default` 工作区解释另一个 PBW。

缺少 `verify.json`、`report.md` 或 `source-hygiene.json` 时，先建议运行 `pbbridge workspace readonly-sync`；只需查看已有证据时可用 `pbbridge workspace readonly-sync --summary-only`。缺少 release-check JSON 时，先建议运行 `pbbridge release check --allow-blocked-result`；3.8.0 起 stdout 默认已经是 `pbbridge-v3-compact-summary`，外部项目也可继续运行 `scripts/pbbridge-release-check.ps1 -AllowBlockedResult`。release-check 是只读聚合门禁，不自动生成共享库检查或 IDE Full Build 证据，compact stdout 不替代完整 release-check JSON，自动化必须读取 `resultJsonPath`。提交前需要短结论时运行 `pbbridge git precommit-summary` 或兼容脚本 `scripts/pbbridge-precommit-summary.ps1`，但它不替代 release-check。
缺少共享库门禁证据时，优先运行 `pbbridge shared-library writeback-check --project-root . --allow-blocked-result`；外部项目脚本只作为同名入口包装。该门禁只消费当前 `verify.json`，不读取旧 verify 文件名，不提交、不推送、不更新 submodule pointer。配置内共享库在专家链路 gate 通过后默认允许继续 Apply/WriteBack；gate blocked、证据缺失或脚本异常不能当作允许写回。
如果用户说明 `.pbl` 是在 PowerBuilder IDE 中直接修改，优先建议运行 `pbbridge pbl change-intake`；外部项目脚本只是同名包装入口。
如果用户说明本轮只完成 `.sr*` 选择、暂不写回 PBL，优先读取 `.pbbridge/source-accepted-checklist.json`；该清单只能证明 source-only accepted，不等于 PBL 已同步，也不等于 IDE Full Build 已完成。

## 阻断规则

1. `.pbbridge/workspaces/` 被跟踪或暂存：阻断。
2. verify 有本轮新增 Error、过期 waiver 或 strict 下未覆盖 Warning：阻断。
3. `.pbl` 漂移没有 `.sr*` diff、import/post-review、共享库门禁、`pbl-drift-evidence.json` 或 `.pbbridge/policies/pbl-binary-baselines.json` 明确解释：阻断；若 `decision.currentChangeBlocked=false` 但 `decision.historicalBlocked=true`，必须把历史问题和本次提交判断分开说明。
4. 无关 `.pbd/.exe`、临时包、诊断日志或缓存进入暂存：阻断。
5. submodule 内有未提交变更，或父仓库指针未提交：阻断。
6. 共享库配置存在但缺少 shared-library gate JSON：阻断。
7. 未运行 readonly sync 或 Source Layout 无法证明当前受管控 PBL：阻断。
8. IDE Full Build、Regenerate、运行验收缺失时，不一定阻断提交，但必须列为发布剩余验收项。
9. release-check 或 remediation 显示 `.pbl` 漂移仍未解释时阻断；若已由 import/post-apply/shared-library/manual evidence 或可提交二进制基线解释，仍必须说明 IDE Full Build 和运行验收状态。
10. `.pbbridge/source-accepted-checklist.json` 只能支持“源码已选定、PBL 暂不同步”的结论；如果发布声明需要 PBL 已同步，仍必须补齐 PowerBuilder IDE Regenerate / Full Build / 运行验收或正式 writeback 证据。
11. 进入 PbBridge/Toolkit 版本发布流程时，release engineering summary 中 `status=blocked`、`tagGuard.status=blocked` 或 `releaseAssetHandoff.status=blocked` 必须阻断发布；`tagGuard.tagMoveRequired=true` 必须说明是否显式传入允许移动 tag 的参数；`releaseProvenance` 缺失时必须先升级发布工程脚本。
12. 不得把 `-AllowPublishedTagMove` 当作常规发布路径；只有维护者明确说明要重指向 tag 时才可使用，并且发布交接必须高亮风险。
13. docs/spec/skill 治理 lint 失败时不得继续发布；先修正文档事实源或明确历史快照边界，再重新生成 release engineering summary。
14. `project drift check` 的 blocked drift、shared-library consumer 写回冲突、source layout blocking drift 或 baseline 与当前项目模型不一致时，不得继续 Apply 或发布。
15. `writeback readiness check` 的 blocked stage 不能被 PowerShell wrapper、Toolkit skill 或 SharpIDE 覆盖；只能回到 CLI/Core JSON facts、项目模型、shared-library evidence 和 IDE 验收证据补齐。
16. 3.6.0 起，如果 command descriptor 与 `schema show`、`contract validate`、help 或 route coverage 不一致，按发布阻断处理；不能靠文档或 wrapper 临时修正。
17. diagnostics bundle 出现未标记 local-only 的本机路径、敏感信息或 `.pbbridge/workspaces` 大量临时内容时，按证据治理阻断处理。

## 输出要求

结束时使用 `skills/_shared/handoff-template.md` 的字段，并给出明确结论：

1. `可发布`：release-check 未阻断，Git 状态干净或变更已解释，IDE 验收状态清楚。
2. `暂不可发布`：列出阻断项、证据路径和下一条命令。
3. `只能提交源码，不能宣称发布`：CLI 证据通过但 IDE Full Build 或业务验收未完成。
4. `发布工程需人工确认`：release/tag guard 或 release asset handoff 为 warning，尤其是显式允许移动 tag、tag 未推送、Toolkit commit 远端可达性未知或本地/远端 tag 状态需要人工处理。

不要把 `source-hygiene.json` 单独当作 `.pbl` 漂移解释证据；它只能证明做过源码卫生检查。
如果存在 `.pbl` 漂移，优先读取 `.pbbridge/pbl-drift-remediation.json`；缺失时建议运行 `scripts/pbbridge-pbl-drift-remediation.ps1`。remediation 中 `stillBlocking=true` 的项仍按阻断处理，`pbl-lfs-filter-mismatch` 只解释 Git filter 异常，不单独放行。
如果 `.pbl` 漂移来自 PowerBuilder 编译选项、project options 或经评审 metadata-only 变化，应使用 `pbbridge-pbl-binary-baseline` 创建 `.pbbridge/policies/pbl-binary-baselines.json`，再运行 remediation 与 release-check。二进制基线证据可解释漂移来源，但不等于 IDE Full Build 已完成。
`.pbbridge/pbl-drift-remediation.json` 可以作为提交 `.pbl` 时的漂移解释证据保留；`.pbbridge/workspaces/`、`.pbbridge/cache/`、`.pbbridge/diagnostics-bundle*/`、`.pbbridge/pbl-change-intake.json`、`.pbbridge/release-check.json`、`.pbbridge/project-health.json`、`.pbbridge/precommit-summary.json` 和其他根级本机 workflow state JSON 默认是本机运行产物，不应作为稳定源码事实源提交，除非 `.pbbridge/evidence-policy.json` 明确要求。
`.pbbridge/source-accepted-checklist.json` 可作为协作交接清单提交与否取决于项目规则；无论是否提交，都不能替代 PowerBuilder IDE 的 Regenerate / Full Build / 运行验收结论。
`verifyScope=object` 或 `target-pbl` 只能作为对象级导入降噪证据；发布判断必须回到 `verifyScope=all`、release-check、IDE Full Build 和运行验收。若存在 `postApplyReviewDrifts[]`，优先按 `severity=error` 与 `driftKind=semantic|structural` 判断阻断。

2.7.1 起，`ForceApply` 仍不得作为绕过 verify 阻断项的发布证据；尤其是 `PBV076`，必须先修复 `.srf` 结构污染并重新生成 plan。发布前如果外部项目仍使用旧 `pbbridge-import-sr.ps1`，应先升级模板以避免 PBL drift guard 空集合绑定问题。
2.7.2 起，遇到 `project-health blocked`、`PBV076 managed-blocker`、缺 source-hygiene/release-check、缺 `.pbbridge/shared-libraries.json`、未解释 `.pbl` drift 或 dirty shared submodule，优先引用 `docs/reference/project-health-blocked清理指引.md` 的顺序清理：Git/submodule、verify blocker、共享库边界、只读证据、drift evidence、IDE 验收。
高风险对象导入包的 apply 结果可以作为写回证据之一，但不替代 IDE Regenerate / Full Build / 运行验收，也不改变 PB9 支持矩阵。
如果存在 admission evidence，只能把 `candidate-evidence-collected` 或 `candidate-reproducible` 写成候选证据状态；正式 `supported` 必须另有支持矩阵评估和发布说明变更。
