---
name: pbbridge-cli
description: 使用 PbBridge.Toolkit 6.0.0 CLI 处理 PowerBuilder 源码、V6 delivery、诊断与 IDE 交接。
---

# PbBridge CLI

## 何时使用

- 定位、导出、校验或比较 `.sr*` 对象
- 执行 V6 DryRun、Apply 或 ApplyIfEligible
- 校验 V6 schema、生成 IDE checklist/handoff
- 运行项目健康、只读同步、发布门禁或诊断 evidence

不确定命令时先运行 `pbbridge toolkit entrypoints explain --intent <intent>`；对象意图包括 `object-find|object-export|object-repair|object-diff`，日常写回 intent 为 `daily-writeback`。

## 日常交付主路径

对象键必须是 `<target-pbl>:<object-type>:<object-name>`，对象参数为 `<object-key>=<source-path>`。

```powershell
# DryRun
pbbridge delivery close-loop --object "app.pbl:window:w_example=src/app.pbl.src/w_example.srw" --progress text --result .pbbridge/local/results/delivery-v6/dryrun.json

# Apply
pbbridge delivery close-loop --object "app.pbl:window:w_example=src/app.pbl.src/w_example.srw" --apply --preflight-result .pbbridge/local/results/delivery-v6/dryrun.json --result .pbbridge/local/results/delivery-v6/apply.json

# ApplyIfEligible
pbbridge delivery close-loop --object "app.pbl:window:w_example=src/app.pbl.src/w_example.srw" --apply-if-eligible --policy .pbbridge/policies/auto-apply.json --result .pbbridge/local/results/delivery-v6/auto.json
```

PowerShell wrapper 使用 `scripts/pbbridge-delivery-close-loop.ps1`。wrapper 是薄适配层，不得自行判断 readiness、policy、writeback 或 review。

## 判读顺序

1. stdout 验证 `schemaName=pbbridge-v6-compact-summary`，然后读取 `resultJsonPath`。
2. full JSON 必须为 `pbbridge-v6-delivery` / schema 6。
3. 读取 `phase`、`outcome` 与 canonical `summary`。
4. 分别检查 `apply`、`policy`、`writeback`、`diff`、`conflicts`、`review`、`recovery`。
5. 对象存在性只读 `objects[].existence` / `objects[].review.existence`；`not-checked` 不得解释为不存在。
6. 计划差异读取 `diff.planned`，写回后残余差异读取 `diff.residual`。
7. 执行结构化 `nextCommand`，不要从 human summary 拼命令。

## 契约诊断

```powershell
pbbridge schema show pbbridge-v6-delivery
pbbridge schema explain pbbridge-v6-delivery
pbbridge schema show pbbridge-v6-compact-summary
pbbridge contract validate .pbbridge/local/results/delivery-v6/apply.json
```

收到 `unsupported-schema-version` 时必须升级 Toolkit 并重新运行 V6 DryRun。禁止改 schema、使用字段别名或调用旧 mapper。

## 源码格式

`objects[].sourceFormat.current/original/delta/classification` 是唯一格式解释入口。先区分 Git 属性预期转换、纯格式噪声与业务内容变化，再决定是否阻断。不得把单条 Git 行尾提示直接当作源码污染。

## IDE 交接

```powershell
pbbridge delivery ide-checklist --result .pbbridge/local/results/delivery-v6/apply.json
pbbridge delivery ingest-ide-log --result .pbbridge/local/results/delivery-v6/apply.json --log .pbbridge/local/ide/full-build.log
pbbridge delivery handoff-summary --result .pbbridge/local/results/delivery-v6/apply.json
```

CLI 写回成功不等于 IDE 通过。最终必须记录 Regenerate、Full Build 和运行验收结果。

## 专家入口边界

V4 import/writeback 命令只能用于隔离排障，结果不能传入 V6 handler、workflow、presenter、cache 或 handoff。日常交付不得从专家结果重新聚合 summary。

## 安全规则

- DryRun 不修改 PBL。
- Apply 必须引用同一请求的新鲜 V6 preflight result。
- ApplyIfEligible 必须使用共享策略 evaluator。
- token 只通过环境变量或文件引用传入，明文不得写入 stdout、stderr、result 或 evidence。
- `.pbbridge/local/` 与 IDE 临时证据默认不提交。
