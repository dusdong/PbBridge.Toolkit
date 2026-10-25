---
name: pbbridge-contract-diagnostics
description: 诊断 PbBridge 当前 V8 delivery/session schema、一致性、非当前输入拒绝、工作区身份与退出码问题。
---

# PbBridge V8 契约诊断

## 优先命令

```powershell
pbbridge schema show pbbridge-v8-delivery
pbbridge schema explain pbbridge-v8-delivery
pbbridge schema show pbbridge-v8-compact-summary
pbbridge schema show pbbridge-v8-delivery-session
pbbridge contract validate <result-json>
```

## 检查顺序

1. full 必须是 `pbbridge-v8-delivery` / schema 8；compact 必须是 `pbbridge-v8-compact-summary` / schema 8。
2. compact 的 `workflowSchemaName`、`resultJsonPath`、workspace、三层 readiness、canonical summary、`nextAction` 与 blockers 必须和 full 同源。
3. `workspace.id`、repo root、配置、manifest/result/cache/policy/lock/recovery 路径必须属于同一已解析 workspace。
4. `writebackReadiness`、`ideReadiness`、`releaseReadiness` 必须由 application facts 计算；adapter 不得自报 application readiness。
5. 计划差异必须来自 target PBL snapshot；写回前 residual 必须为未评估。
6. 计数同时检查 `evaluationStatus` 与 `count`，不能把未评估解释为零。
7. `objects[].existence=not-checked|unknown` 不能解释为对象缺失。
8. 非当前 schema、旧 preflight 或 facts hash 不匹配必须返回结构化阻断，不能改写 JSON 绕过。

非当前 Delivery/session 不提供 historical reader；升级后必须重新生成当前 V8 preflight/session。
