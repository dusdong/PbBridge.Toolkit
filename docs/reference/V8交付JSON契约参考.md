# V8 交付 JSON 契约参考

当前 full/compact 分别为 `pbbridge-v8-delivery` 与 `pbbridge-v8-compact-summary`，`schemaVersion=8`。

`pbbridge delivery history --session-file <path> [--result <new-independent-json>]` 仅读取已知 7.5.2/7.5.3 V8 session。独立报告为 `pbbridge-delivery-history`、schemaVersion 1、reportMode historical-read-only、canContinue false。readerProductVersion 与 recordedProductVersion 分离；原身份缺失字段由 missingProducerIdentityFields 列明。sessionFileSha256 与解析来自同一快照。recordedState 仅记原状态，currentEvaluationStatus 为 not-evaluated；附件 evaluationStatus 为 not-rechecked，缺失引用 unavailable。该报告不属于当前 Delivery/session/preflight/evidence，当前入口仍拒绝它及原旧 session。

历史报告附件字段独立保真：`recordedType` 仅来自原 `type`，`recordedStatus` 仅来自原 `status`。缺失或非字符串字段省略，表示未知；不得从类型推断状态，也不得从状态补齐类型。路径/哈希仍为原记录文本，附件始终 `not-rechecked`。

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


7.6.0 源码诊断为 additive 扩展：full 的 `objects[].sourceDiagnostics`、compact/summary/explain/handoff 的 `sourceDiagnostics` 共享同一 invocation 投影。字段包括 `invocationId/stage/nativeFunction/ownership/objectKey`、分离的 `nativeReturnCode/messageCode`、原始 `nativeLine/nativeColumn`、`memberName/memberKind`、`mappingStatus/mappingReason`、原字节/快照/实际输入路径与哈希、`absoluteLine/absoluteColumn/currentFileStatus/nextStep/evidencePath`。

只在输入、成员和已验证的运行时/阶段坐标规则唯一可信时 mapped；ambiguous/unmapped 的绝对行列为空。位置属于编译时快照，当前文件变化显示 stale-or-missing；快照/输入缺失或篡改后撤销映射。callback CP936 解码与源码编码分开，完整有序消息及 callback 原字节保存在诊断证据中。下一步分类 `source-error|environment-blocked|manual-verification|unknown` 只解释动作，不改变交付状态、退出码、schemaVersion 或准入。具体原生支持范围须读取对应开发候选证据，不能从托管测试推导全部 PB9 阶段已支持。

编译诊断的 `nextStep` 属于历史调用；当前 `nextAction` 依据所属对象的最终 importer 检查和当前阻断/覆盖另行投影。fallback 恢复成功不删除首次 C0051，也不让它覆盖其他对象的当前源码错误或文件锁。仅通过 availability 预检、缺少终态的旧记录不能据此认定恢复成功。
