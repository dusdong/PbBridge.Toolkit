> 本文档由 `PbBridge.Toolkit` 从父仓库手册同步生成。
> 当前 toolkit 固定提供 `CLI win-x86 + IDE win-x64` 的 Windows 运行时组合；正式写回支持矩阵仍以父仓库事实源为准。
# project-health blocked 清理指引

本页用于外部 PowerBuilder 项目在 `scripts/pbbridge-project-health.ps1` 返回 blocked 后的清理。exit 10 表示健康检查结果 blocked，不等同于脚本异常；exit 1 只表示执行失败，只有 stdout/stderr 明确显示脚本崩溃时才按脚本错误处理。

## 清理顺序

1. 整理 Git 和 submodule：先处理父仓、`pb-libs`、`pb-langchao` 的 staged/unstaged 差异。
2. 修复 `PBV076 managed-blocker`：用 `suggest-fixes --code PBV076` 定位，只修 `.srf` 结构污染，不用 `ForceApply` 绕过。
3. 补 `.pbbridge/shared-libraries.json`：明确共享库路径和 `evidenceMode=self|consumer`。
4. 生成 `source-hygiene.json`，运行 `release-check`，再运行 `project-health` 总览。
5. 对 `.pbl` drift 补 import/post-apply/shared-library evidence、`pbl-drift-remediation.json` 或二进制基线策略。
6. 最后由 PowerBuilder IDE 完成 Regenerate / Full Build / 运行验收。

## 发布边界

`source-hygiene.json` 不能单独解释 `.pbl` 漂移；`ForceApply` 不能绕过 verify blocker；CLI Apply 成功不等于 IDE 编译通过。

## 7.2.2 统一验收摘要

完整 project-health JSON 兼容性增加 `acceptanceSummary`，固定包含 `runtime`、`source`、`upgrade`、`release`、`production` 五个维度。应先读取 `acceptanceSummary.verdict`，再按维度的 `status/reasonCodes/evidencePaths` 定位证据；compact stdout 同源输出 `acceptanceVerdict`。

`release` 维度直接保留 release-check 原始阻断，即使旧 project-health check 为共享库缺配置做 warning 映射也不会丢失。`release=clear` 时 `production` 仍固定为 `pending`，表示真实 Apply、PBL 反导复核、IDE Full Build 和业务运行未完成；7.2.2 不输出 `production-ready`。
