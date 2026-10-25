---
name: pbbridge-verify-triage
description: 当用户贴出 PbBridge verify.json、PBVxxx 规则问题、baseline/waiver 摘要、过期 waiver、新增 Error/Warning、PBV076/PBV055 结构污染或源码布局问题，并需要分类、降噪、修复/豁免/暂缓建议时使用。
---

# PbBridge Verify Triage

使用本 skill 处理 `verify` 结果，不替代 `pbbridge-cli` 的命令执行，也不替代 PowerBuilder IDE 编译验收。目标是把 `verify.json` 中的问题分成“必须修复”“可由 baseline/waiver 降噪”“需要人工确认后暂缓”。

## 输入证据

优先读取：

1. `.pbbridge/workspaces/default/artifacts/pbbridge/verify.json`
2. `.pbbridge/workspaces/default/artifacts/pbbridge/report.md`
3. `.pbbridge/verify-baseline.json`
4. `.pbbridge/verify-waivers.json`
5. 本轮 `git diff -- . *.sr*` 与任务描述

如果 `verify.json` 包含 `baselineSummary`，以其中的 `newIssueCount`、`knownIssueCount`、`waivedIssueCount`、`expiredWaiverCount` 和 `newBlockingIssueCount` 做降噪判断。known issue 和有效 waiver 不应被重新描述为本轮新增阻断；expired waiver 仍视为策略风险。

大型项目首次接入或重新治理历史问题时，优先使用 verify policy 生命周期入口生成可审计草稿，不手工拼 JSON：

```powershell
PbBridge.Cli.exe verify-policy init-baseline .pbbridge/workspaces/default/artifacts/pbbridge/verify.json --output .pbbridge/verify-baseline.json
PbBridge.Cli.exe verify-policy draft-waivers .pbbridge/workspaces/default/artifacts/pbbridge/verify.json --output .pbbridge/verify-waivers.draft.json
PbBridge.Cli.exe verify-policy audit .pbbridge/workspaces/default/artifacts/pbbridge/verify.json --baseline .pbbridge/verify-baseline.json --waiver .pbbridge/verify-waivers.json --output .pbbridge/verify-policy-audit.json
```

`init-baseline` 与 `draft-waivers` 只生成草稿，必须人工补全 reason、owner、expiresOn 并评审后提交；`audit` 的 `blockingPolicyIssueCount`、`expiredWaiverCount` 与 `nextActions` 应进入本轮结论。

## 分流规则

1. 先按 severity 聚合：Error、Warning、Info。
2. 再按来源分类：本轮新增、baseline 已知、有效 waiver、过期 waiver、无法归类。
3. Error 且属于本轮新增时，默认给修复优先级最高。
4. Warning 在 strict 模式下未被 baseline/waiver 覆盖时，按阻断风险说明。
5. 有效 waiver 只记录为已豁免，不要求重复修复；过期 waiver 给出续期或修复建议。
6. 不能只凭规则码删除源码；必须回到 manifest、Source Layout、对象路径和本轮 diff 验证。
7. 缺少 baseline/waiver 管理入口时，先建议运行 `verify-policy init-baseline` 或 `draft-waivers` 生成草稿，再审计，不建议直接手写策略文件。

## 常见问题建议

1. `PBV076`：优先检查对象是否出现在错误 `src/<normalized-pbl-name>` 下、是否混入共享库或旧导出目录、manifest 的 `sourceRoot` 是否指向当前事实源。
2. `PBV055`：优先检查 PBL 与 `src/<normalized-pbl-name>` 是否一一匹配、是否存在孤立 `.sr*`、是否从 `.pbbridge/workspaces` 误复制了源码。
3. checksum/sourceRoot drift：先刷新 readonly sync 或重新 export，不直接修改 manifest。
4. 共享库对象问题：先判断对象是否属于 submodule；属于共享库时转 `pbbridge-submodule-update` 或 CLI 共享库任务卡处理。

## 输出要求

结束时使用 `skills/_shared/handoff-template.md` 的字段，并至少说明：

1. 新增 Error/Warning 数量与是否阻断。
2. baseline 命中的历史问题数量。
3. waiver 命中、过期和需要续期的问题。
4. 每类问题的建议动作：修复、豁免、续期、暂缓或刷新 baseline。
5. 下一条建议命令，例如 `verify --baseline --waiver`、`report`、readonly sync 或对象级 import DryRun。
6. 如已启用策略文件，说明 `.pbbridge/verify-policy-audit.json` 是否存在，以及是否需要重新运行 `verify-policy audit`。
