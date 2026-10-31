# V8 交付 JSON 契约参考

当前 full/compact 分别为 `pbbridge-v8-delivery` 与 `pbbridge-v8-compact-summary`，`schemaVersion=8`。

`pbbridge delivery history --session-file <path> [--result <new-independent-json>]` 仅读取已知 7.5.2/7.5.3/7.6.0 V8 session。独立报告为 `pbbridge-delivery-history`、schemaVersion 1、reportMode historical-read-only、canContinue false。readerProductVersion 与 recordedProductVersion 分离；原身份缺失字段由 missingProducerIdentityFields 列明。sessionFileSha256 与解析来自同一快照。recordedState 仅记原状态，currentEvaluationStatus 为 not-evaluated；附件 evaluationStatus 为 not-rechecked，缺失引用 unavailable。该报告不属于当前 Delivery/session/preflight/evidence，当前入口仍拒绝它及原旧 session。

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

历史报告默认输出 stdout。显式 `--result` 位于 Git 仓库内时，必须指向最近所属仓库（含 `.git` 文件边界）的既存 `.pbbridge/local/<task>/new.json`，外层仓库不改变归属；仓库外的独立任务目录继续按既有本地路径规则判断。两种情况均须使用本地固定盘上既存的父目录，拒绝链接、受保护路径及记录的 workspace 受管位置，所有祖先的身份与安全检查仍生效。目标只能是新建 JSON，重复路径拒绝且原报告不变。历史读取不会访问记录的 workspace 或附件；当前交付必须重新生成同构建 preflight/session。


### 规范化预览的观察范围

`pbbridge object normalize-preview --repo-root <root> --workspace default --object <key> --source <source> --output-dir <new-task-dir>` 只在新任务目录的副本上编译、反导；原源码、PBL、共享库、基线和 session 不写入。完整 PB9 win-x86 bundle 的正常 CLI 会在首次适配器探测前准备同 bundle 模块，无须手设 PBSPY_HOME、PB_HOME 或额外 PATH；缺件或已加载冲突须更换完整 bundle/使用干净 CLI 进程，不能通过取消模块核验继续。

preview schemaVersion 仍为 1。`protection.scope=related-inputs`，`observedPaths[].path/role` 列出源码及格式、全部实际编译库、project/workspace 配置、PBW 及其 PBT、manifest、对象关联既存基线、CLI 与七个实际运行模块；`notCovered` 说明未引用文件、工具目录、无关历史状态及未引用 sidecar 不在比较范围。`before/after/unchanged` 仅对应此集合，不代表全仓字节守恒。未引用的 node_modules 链接不阻断；同名路径成为实际输入或输出时仍检查链接与身份。相关文件缺失、漂移或观察失败会撤销建议；输出禁区和链接保护独立保留。

仅 preview-ready 提供建议与 patch；审阅变换、原始/建议 Hash 及差异后，采用仍是独立授权的源码修改，并须重新预检。预览不执行 Apply/promotion/recovery、不刷新基线，也不证明 PB IDE Full Build 或业务验收。开发验证工具 `scripts/pb9-source-normalization/validate_preview_only.py` 仅接受 owned 合成 seed，验证函数、菜单、no-changes 和原件保全，不执行采用。

独立预览任务可以位于本项目既存 `.pbbridge/local` 下；根目录放置 PBL 不会将整个项目变成输出禁区。源码根、库文件、专用依赖目录、受管状态/缓存/锁/恢复、canonical baseline 和运行时目录仍禁止输出重叠，所有输入/输出链接检查保持。
