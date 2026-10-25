# V5 IDE 验收指南（历史归档）

> 仅供追溯历史交付。当前 IDE 验收必须消费 V6 full result 或由其生成的 handoff summary。

V5 不替代 PowerBuilder IDE。`canProceedToIdeFullBuild=true` 只表示 PBL 写回闭环可进入 IDE 验收。

```powershell
pbbridge delivery ide-checklist --result <v5-json> --output .pbbridge/local/results/ide-checklist.json
```

按 checklist 在 IDE 中执行：

1. 打开目标 application。
2. Regenerate 受影响对象或 PBL。
3. 运行 Full Build。
4. 执行业务 smoke / runtime acceptance。
5. 保存 IDE 日志。

接入日志：

```powershell
pbbridge delivery ingest-ide-log --result <v5-json> --log <ide-full-build.log> --output .pbbridge/local/results/ide-evidence.json
```

读取 `ideBuildVerdict`、`mappedErrorCount`、`unmappedErrorCount` 和 `ideDiagnostics[]`。
