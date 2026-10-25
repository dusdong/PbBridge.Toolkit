---
name: pbbridge-pbl-drift-remediation
description: 当用户遇到 .pbl Git 漂移、PBL_LFS_FILTER_MISMATCH、PowerBuilder 编译副作用、metadata-only drift、import/post-apply 证据链或需要生成 pbl-drift-remediation.json 时使用。
---

# PbBridge PBL Drift Remediation

使用本 skill 处理 `.pbl` 漂移解释和修复计划。它是只读诊断优先的 workflow，不替代 `release-check`，也不自动提交、推送或绕过门禁。

如果用户说明 `.pbl` 是在 PowerBuilder IDE 中直接修改，或用户预期 `src/**/*.sr*` 应该出现文本 diff 但当前 `srDiff=false`，应转用 `pbbridge-pbl-change-intake`。本 skill 只能解释 drift 来源，不能证明 `.sr*` 文本投影已经刷新。

## 必读证据

1. `git status --short --branch`
2. `.pbbridge/pbl-drift-remediation.json`
3. `.pbbridge/release-check.json`
4. `.pbbridge/workspaces/default/artifacts/pbbridge/import-result*.json`
5. `.pbbridge/workspaces/default/artifacts/pbbridge/*post-apply*.json`
6. `.pbbridge/shared-library-writeback-check*.json`
7. `.gitattributes` 和 `git check-attr filter -- <path>.pbl`

缺少 remediation JSON 时，先建议运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-pbl-drift-remediation.ps1
```

同仓多 PBW 项目必须传入当前 PBW 的命名工作区：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-pbl-drift-remediation.ps1 -WorkspaceName kuaican
```

## 分类规则

1. `import-writeback-explained`：必须有 import result、plan、DryRun/Apply 或 diagnostics bundle 证据。
2. `metadata-only-drift`：必须来自 post-apply review，正文漂移为 0，仅 metadata-only 计数大于 0。
3. `shared-library-pointer-explained`：必须有共享库 gate 或 submodule 指针交接证据。
4. `pbl-lfs-filter-mismatch`：说明 Git filter 历史异常，不代表业务对象必然变化，也不能单独放行漂移。
5. `binary-baseline-reviewed`：来自可提交的 `.pbbridge/policies/pbl-binary-baselines.json`，用于解释 PowerBuilder 编译选项、project options 或经评审 metadata-only 变化。
6. `powerbuilder-compile-option-baseline`：`reasonCode=powerbuilder-compile-options` 的二进制基线证据；此类变化不要求 `.sr*` 语义 diff。
7. `powerbuilder-build-drift-unverified`：通常来自 IDE 编译副作用；需要 restore、重新导出或二进制基线证据。
8. `unexplained-pbl-drift`：仍阻断 release-check 和发布判断。

## 安全边界

1. 默认只读，不修改 `.pbl`、`.sr*`、Git index、submodule 指针或 release-check 结果。
2. `-ApplySafeWorkspaceFixes` 只允许执行 remediation plan 中的 Git filter 工作区恢复，不得改业务对象内容或隐藏 Git 状态。
3. 不使用 `assume-unchanged` 作为持久方案；只能在明确说明原因的临时排查中使用，并且必须恢复。
4. `source-hygiene.json` 不能单独解释 `.pbl` 漂移。
5. `import-writeback-explained` 或 `stillBlocking=false` 不等于 `.sr*` 文本投影已经刷新；需要反导出时使用 `pbbridge pbl change-intake`。
6. 已评审的编译选项或 project options 变化应通过 `pbbridge-pbl-binary-baseline` 维护可提交策略，不要长期依赖本机 `pbl-drift-evidence.json`。

## 输出要求

结束时说明：

1. 每个 `.pbl` 的分类和 `stillBlocking`。
2. LFS mismatch 是否存在，以及它只是 Git filter 历史异常。
3. 哪些证据可以随提交保留，哪些漂移仍需处理。
4. 下一条命令：remediation、release-check、readonly sync、import DryRun/Apply 或 Git restore。
5. 如果用户预期 `.sr*` 应变化，明确建议运行 `pbbridge pbl change-intake`；外部项目脚本只是同名包装入口。
