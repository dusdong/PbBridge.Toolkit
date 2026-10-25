# V5 交付 JSON 契约参考（历史归档）

> 本文不再是可执行契约。CLI 会以 `unsupported-schema-version` 拒绝 V4/V5 delivery JSON，且不会静默映射字段。

V5 full JSON schemaName 为 `pbbridge-v5-delivery-close-loop`，stdout compact summary schemaName 为 `pbbridge-v5-compact-summary`。

稳定顶层字段：

1. `deliveryVerdict`
2. `canProceedToIdeFullBuild`
3. `canApply`
4. `requiresUserConfirmation`
5. `requiresManualRecovery`
6. `businessDiffCount`
7. `formatOnlyDiffCount`
8. `writtenObjectCount`
9. `sourceMatchesObjectCount`
10. `failedObjectCount`
11. `notWrittenObjectCount`
12. `pendingApplyObjectCount`
13. `blockedItems[]`
14. `ideChecklistCommand`
15. `nextCommand`
16. `humanSummaryText`
17. `performanceSummary`

DryRun 未写回的对象进入 `pendingApplyObjectCount` 和 `notWrittenObjectCount`，不得计入真实 `failedObjectCount`。Apply 后 `deliveryVerdict=ready-for-ide-validation` 或 `ready-with-format-warnings` 时，`canProceedToIdeFullBuild=true` 且 `ideChecklistCommand` 指向当前 result。

`blockedItems[]` 在 full JSON 和 compact summary 中必须同源一致，最多输出前三个阻断摘要；成功或 warning-only 场景固定输出空数组 `[]`，不得输出 `null`。该字段只用于快速交接，不替代 full JSON 的 `objects[]`、`pblBatches[]`、`checks[]` 和 source diagnostics。

`delivery handoff-summary --result <v5-json>` 会从 full JSON 派生 Codex/人工交接摘要，稳定输出 `modifiedObjects[]`、`writtenPbls[]`、`sourceMatchSummary`、`ideNextAction`、`evidenceToKeep[]`、`localOnlyDoNotCommit[]`、`gitHygieneResultJsonPath` 和 `formatNoiseSummary`。`evidenceToKeep[]` 只保留具体证据文件或明确结果文件，过滤项目根、workspace 根、磁盘根和 `.pbbridge/` 根等过宽目录；过滤发生时 `handoffSummaryText` 包含 `filteredEvidencePathCount`。

`performanceSummary.cacheMisses[]` 的 `reasonCode` 必须稳定表达 workspace、manifest、source、target PBL、compile libraries、DataWindow validator 或配置漂移；`slowStages[]` 输出慢阶段、耗时占比和原因。cache hit/miss 不改变 verdict、写回计数或退出码语义。

IDE evidence 使用独立 JSON，不覆盖原 delivery result。`delivery ingest-ide-log` 的 `mappedFixTargets[]` 是 Codex 修复 `.sr*` 的主入口。
