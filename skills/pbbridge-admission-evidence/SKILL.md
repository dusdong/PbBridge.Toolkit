---
name: pbbridge-admission-evidence
description: 当用户要采集、验证或解释 PBSpyORCA candidate 支持矩阵候选准入证据、admissionLevel、failure evidence、candidate-reproducible 或 smoke-summary 时使用。
---

# PbBridge Admission Evidence

本 skill 用于处理支持矩阵候选项的证据采集和解释。它不升级正式支持矩阵，也不把单次 smoke 成功解释为正式支持承诺。

## 准入等级

1. `unsupported`：缺少关键证据，不能作为候选项解释。
2. `candidate-evidence-collected`：doctor 或失败证据已采集，可离线复核，但运行时或 workflow 未闭合。
3. `candidate-reproducible`：doctor、写回 smoke、re-export、diff、rollback 和 release gate 证据链闭合。
4. `supported`：只能由独立支持矩阵评估和发布说明更新产生，不能由 admission 脚本自动设置。

## 默认流程

1. 先确认当前仓库和目标证据目录。
2. 运行采集脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\collect-pbspy-x86-admission-evidence.ps1 -AllowUnavailable
```

3. 离线验证失败证据包：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-pbspy-x86-admission-evidence.ps1 -EvidenceRoot .\artifacts\ci\pbspy-x86-admission -AllowFailureEvidence
```

4. 在真实 x86 PBSpy/PBSDK runner 上验证可复现 workflow：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-pbspy-x86-admission-smoke.ps1 -RequireWorkflow
```

5. 读取 `validation.json` 与 `smoke-summary.json`，只按 `admissionLevel` 解释状态。

## 解释规则

1. `candidate-evidence-collected` 只能说明证据已留存，不能说明写回链路可复现。
2. `candidate-reproducible` 仍不是正式支持；必须经过独立支持矩阵评估后，才允许在发布文档中改为 `supported`。
3. 任何 `supported` 结论都必须能回链发布说明、支持矩阵评估记录和对应 release gate 证据。
4. admission 证据可以由 `pbbridge-project-health.ps1` 展示，但候选状态不应成为 release-check 阻断条件。

## 结束汇报

结束时说明：

1. evidence bundle 路径。
2. `validation.json` 或 `smoke-summary.json` 路径。
3. `admissionLevel`。
4. 是否达到 `candidate-reproducible`。
5. 是否仍需要独立支持矩阵评估。
