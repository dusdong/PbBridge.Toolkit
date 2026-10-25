---
name: pbbridge-contract-diagnostics
description: 诊断 PbBridge V6 delivery full/compact schema、一致性、旧版本拒绝和退出码问题。
---

# V6 契约诊断

CLI command descriptor 是路由事实源；诊断 bundle 中的 `workflowFact` 与 `localOnlyEvidence` 用于解释命令契约和本机证据边界。

## 优先命令

```powershell
pbbridge schema show pbbridge-v6-delivery
pbbridge schema explain pbbridge-v6-delivery
pbbridge schema show pbbridge-v6-compact-summary
pbbridge contract validate <result-json>
```

## 检查顺序

1. full 必须是 `pbbridge-v6-delivery` / schema 6；compact 必须是 `pbbridge-v6-compact-summary` / schema 6。
2. compact 的 `workflowSchemaName` 和 `resultJsonPath` 必须指向 V6 full result。
3. full/compact 的 `outcome`、canonical `summary`、`nextCommand` 与 `blockedItems` 必须一致。
4. 计数必须同时检查 `evaluationStatus` 与 `count`，不能把未评估解释为零。
5. `objects[].existence=not-checked|unknown` 不能解释为对象缺失。
6. 进程退出码由 typed outcome 映射，不从 stdout 文本推断。

旧 delivery 输入返回 `unsupported-schema-version` 是预期行为。解决方法是升级 Toolkit 并重新运行 V6 DryRun，禁止修补 schema 或字段映射。
