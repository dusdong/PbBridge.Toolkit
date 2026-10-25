---
name: pbbridge-pbl-binary-baseline
description: 当用户说明 .pbl 变化来自 PowerBuilder 编译选项、project options、metadata-only 或其他已评审二进制变化，需要创建或更新 .pbbridge/policies/pbl-binary-baselines.json 时使用。
---

# PbBridge PBL Binary Baseline

使用本 skill 把 `.sr*` 不可见但经人工评审的 `.pbl` 二进制变化登记为可提交策略证据。典型场景是 PowerBuilder IDE 修改编译选项、project options、application metadata 或经评审的 metadata-only 变化。

## 使用前判断

优先确认三件事：

1. 这次 `.pbl` 变化是否已经由 PowerBuilder IDE 评审确认。
2. 是否已经运行 readonly sync 或 intake，确认没有遗漏本应投影到 `.sr*` 的业务源码变化。
3. 工作区 `.pbl` 是否是真实 PBL，而不是 Git LFS pointer 文本；若出现 `PBL_WORKTREE_LFS_POINTER`，必须先 `git lfs pull` 或恢复真实 PBL。

如果用户预期 `.sr*` 应该有业务 diff，先使用 `pbbridge-pbl-change-intake`。如果用户只是在做漂移分类和阻断解释，先使用 `pbbridge-pbl-drift-remediation`。

## 标准命令

单 PBW 或 default 工作区：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-pbl-binary-baseline.ps1 -WorkspacePath CanYin.pbw -PblPath cy_ht.pbl -ReasonCode powerbuilder-compile-options -Reason "PowerBuilder IDE compile options baseline"
```

同仓多 PBW 必须显式传 `-WorkspaceName`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-pbl-binary-baseline.ps1 -WorkspaceName kuaican -WorkspacePath KuaiCan.pbw -PblPath kc_ht.pbl,kc_lptprn.pbl,kc_qt.pbl -ReasonCode powerbuilder-compile-options -Reason "PowerBuilder IDE compile options baseline"
```

支持的 `ReasonCode`：

1. `powerbuilder-compile-options`
2. `project-options`
3. `metadata-only-reviewed`
4. `other-reviewed`

## 证据规则

生成或更新的策略文件是：

```text
.pbbridge/policies/pbl-binary-baselines.json
```

该文件可以提交，但必须满足：

1. `workspaceName` 与实际命名工作区一致。
2. `workspacePath` 指向具体 `.pbw`，例如 `KuaiCan.pbw`。
3. `pblPaths[]` 只包含本次评审过的 `.pbl`。
4. `reviewedBy` 与 `reviewedAt` 可审计。
5. `reason` 说明为什么该变化不需要 `.sr*` diff。

不要把 `.pbbridge/workspaces/**/artifacts/pbbridge/pbl-drift-evidence.json` 当作长期证据；它只是本机临时兼容输入。

## 复核流程

登记后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-pbl-drift-remediation.ps1 -WorkspaceName <name>
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-release-check.ps1 -WorkspaceName <name> -AllowBlockedResult
```

期望结果：

1. 对应 `.pbl` 分类包含 `binary-baseline-reviewed`。
2. `ReasonCode=powerbuilder-compile-options` 时还包含 `powerbuilder-compile-option-baseline`。
3. 没有 `.sr*` diff 且只有二进制基线证据时，用 intake 的 `checks[]`、`evidence[]` 和 `nextActions[]` 说明该结论。
4. `PBL_LFS_FILTER_MISMATCH` 仍只作为 Git 策略诊断，不作为业务漂移解释。

## 输出要求

结束时说明：

1. 更新的策略文件路径。
2. `workspaceName`、`workspacePath` 和 `pblPaths[]`。
3. `reasonCode`、`reviewedBy`、`reviewedAt`。
4. drift remediation 与 release-check 是否已消费该证据。
5. 是否仍需 PowerBuilder IDE Full Build 或业务运行验收。
