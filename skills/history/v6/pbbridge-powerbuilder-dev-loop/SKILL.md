---
name: pbbridge-powerbuilder-dev-loop
description: 在真实 PowerBuilder 项目中完成 .sr* 修改、V6 DryRun/Apply、反向确认与 IDE 验收闭环。
---

# PowerBuilder 开发闭环

## 读取顺序

1. 外部项目 `AGENTS.md`
2. `.pbbridge/PbBridge.Toolkit/CODEX-START.md`
3. `pbbridge-cli` skill
4. 涉及 PowerScript 时读取 `powerbuilder-powerscript` skill

## 标准流程

1. 通过 manifest 或 `pbbridge object find` 确认 `<target-pbl>:<object-type>:<object-name>` 与 source path。
2. 修改最小范围 `.sr*`，先做语法、DataWindow 结构和 source format 检查。
3. 执行 V6 DryRun，确认 `outcome=ready-to-apply`、技术 readiness、计划差异和 blockers。
4. 用户明确写回时执行 V6 Apply；项目策略授权时使用 ApplyIfEligible。
5. Apply 后读取 canonical summary、writeback、review、conflicts、recovery 与对象级 evidence。
6. 运行 V6 IDE checklist/handoff，在 PowerBuilder IDE 完成 Regenerate、Full Build 和业务运行验收。
7. 只提交业务源码、必要 PBL 与批准的审计证据；local-only 文件不提交。

## 命令

```powershell
pbbridge delivery close-loop --object "app.pbl:window:w_example=src/app.pbl.src/w_example.srw" --result .pbbridge/local/results/delivery-v6/dryrun.json
pbbridge delivery close-loop --object "app.pbl:window:w_example=src/app.pbl.src/w_example.srw" --apply --preflight-result .pbbridge/local/results/delivery-v6/dryrun.json --result .pbbridge/local/results/delivery-v6/apply.json
pbbridge delivery handoff-summary --result .pbbridge/local/results/delivery-v6/apply.json
```

旧 delivery JSON 不得复用；收到 `unsupported-schema-version` 时必须重新运行 V6 DryRun。
