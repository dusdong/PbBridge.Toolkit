# V8 交付 JSON 契约参考

当前 full/compact 分别为 `pbbridge-v8-delivery` 与 `pbbridge-v8-compact-summary`，`schemaVersion=8`。

状态分为 `writebackReadiness`、`ideReadiness`、`releaseReadiness`。`verificationCoverage` 固定包含：

- `sourceReadable`
- `targetSnapshot`
- `conflictPrecheck`
- `pblWriteback`
- `postApplyReview`
- `pbCompile`
- `packaging`
- `deployment`
- `runtime`
- `business`

覆盖状态只能是 `verified`、`attested`、`failed`、`not-checked`、`not-applicable`。发布状态为 `not-ready`、`ready-with-attestations` 或 `ready`。

`nextAction.type` 只能是 `command` 或 `manual-action`。Full Build 必须是 `manual-action`。

其他公共契约包括 delivery session、IDE checklist、acceptance、IDE log、target packaging、target deployment 和 handoff；可用 `pbbridge schema show <schemaName>` 查看字段摘要。
