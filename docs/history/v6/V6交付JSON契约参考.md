# V6 交付 JSON 契约参考

## Schema

- full：`schemaName=pbbridge-v6-delivery`、`schemaVersion=6`
- compact：`schemaName=pbbridge-v6-compact-summary`、`schemaVersion=6`
- workflow：`delivery-close-loop`

```powershell
pbbridge schema show pbbridge-v6-delivery
pbbridge schema explain pbbridge-v6-delivery
pbbridge schema show pbbridge-v6-compact-summary
pbbridge contract validate .pbbridge/local/results/delivery-v6/apply.json
```

## Full 顶层

`phase`、`outcome`、`summary`、`apply`、`writeback`、`diff`、`conflicts`、`review`、`policy`、`recovery`、`performance`、`objects[]`、`pblBatches[]`、`checks[]`、`evidence[]`、`artifacts[]`、`blockedItems[]`、`nextCommand` 与 `humanSummaryText`。

## Canonical summary

`plannedObjectCount` 是本次请求对象数。其余计数使用 `{ evaluationStatus, count }`，包括 `plannedSourceDiffs`、`dryRunFailures`、`applyFailures`、`pblWritebacks`、`writtenObjects`、`sourceMatches`、`formatResidualDiffs`、`businessResidualDiffs`、`conflicts` 与 `reviews`。

布尔主事实包括 `partialWriteback`、`recoveryRequired`、`canProceedToIdeFullBuild`，并包含 `blockedItemCount`。compact 直接复用该对象，不重新聚合。

## 正交状态

- `phase`：当前执行阶段
- `outcome`：最终业务结论
- `apply.readiness`：技术 Apply 准入
- `policy.decision` / `reasonCodes[]`：策略准入
- `writeback.outcome`：写回结论
- `review.evaluationStatus`：反导复核是否已评估
- `diff.planned` / `diff.residual`：计划变化与写回后残余差异
- `objects[].existence`：`exists|missing|not-checked|unknown`

## 一致性与拒绝规则

full/compact 的 `summary`、`outcome`、`nextCommand` 和 `blockedItems` 必须一致。V4/V5 或未知版本输入返回 `unsupported-schema-version`，调用方必须重新运行 V6 DryRun。
