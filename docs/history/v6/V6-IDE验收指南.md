# V6 IDE 验收指南

V6 Apply 完成后先确认 `summary.canProceedToIdeFullBuild=true`，再生成清单：

```powershell
pbbridge delivery ide-checklist --result .pbbridge/local/results/delivery-v6/apply.json --output .pbbridge/local/ide/checklist.json
```

在 PowerBuilder IDE 中执行：

1. 打开目标 PBW/PBT，核对目标 PBL 与对象。
2. 对变更对象执行 Regenerate。
3. 执行 Full Build，保存完整日志。
4. 运行受影响业务场景，记录人工验收证据。

回传日志并生成交接摘要：

```powershell
pbbridge delivery ingest-ide-log --result .pbbridge/local/results/delivery-v6/apply.json --log .pbbridge/local/ide/full-build.log --output .pbbridge/local/ide/evidence.json
pbbridge delivery handoff-summary --result .pbbridge/local/results/delivery-v6/apply.json --output .pbbridge/local/ide/handoff.json
```

所有命令只接受 V6 full result。旧结果必须重新执行 V6 DryRun/Apply。
