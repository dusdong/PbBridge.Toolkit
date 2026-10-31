> 本文档由 `PbBridge.Toolkit` 从父仓库手册同步生成。
> 当前 toolkit 固定提供 `CLI win-x86 + IDE win-x64` 的 Windows 运行时组合；正式写回支持矩阵仍以父仓库事实源为准。
# DataWindow 分类与 PB9 验收

## PB760-P13：当前人工验收收口（2026-10-28）

PB9 IDE构建：验收通过（所有者确认）；物业业务实际验收：验收通过（所有者确认）。两项以owner-attested记录，不再索要用户已豁免的路径/日志或session关联；其他11项自动化通过，包含P12实际数据库原件重核。3.4完成、任务12/12，formalAuthorization=false、publishable=false。本包没有重跑数据库或取得新的原生日志；详情及交接见[当前发布入口](93-7.6.0发布说明.md)。下文P12/P04仍为历史实测范围。
## 历史PB760-P12：新PB9数据库实证（2026-10-27）

P04原件已由所有者清理，其历史缺失保持。P12在新独占schema执行PB9 x86/ODBC17实测：21项原断言及3项新增负向断言通过，参数化Retrieve返回id=2/label=p12-two，坏Create和坏列Retrieve均返回-1并保留原错误。新原件为`F:\CodexRuns\PB760-P12-20261027\native\run-04\native-results.txt`（CP936）；PBVM90来自不变候选，PBODB90来自已安装PB9 9.0.3.8836，32位驱动实际加载Hash另存。schema按对象ID、时间、token、元数据及内容核验清理；真实SQL反例证明错误ID/内容变化拒绝清理。

新显式任务参数保留P04默认入口，详见[生产发布说明](11-生产发布说明.md)及[P12交接](../../.pbbridge/local/task-packages/PB760-P12-native-business-20261027/handoff/candidate-v01-handoff.md)。当前消费者11/13项通过，IDE与owner仍未验，3.4不勾选；71项组件测试不代替现场业务验收。下文旧包描述只保留历史覆盖。

`datawindow inspect` 与 `datawindow validate` 保留既有字段，并追加 `sourceDefinitionKind`、`parseCompleteness`、`classificationEvidence[]` 和 `populationUsage`。直接 `.srd` 与 object-key 输入共用解析。没有可信调用上下文时用法为 `unknown`；窗口没有 Retrieve、用户声明 memory-fill 或 SQL 为空，都不能豁免定义检查。

完整合法 external 需要完整 datawindow/table、非空唯一列名、可识别 PB9 类型及正确视觉列 id/名称绑定。它不需要 SQL，也不会被自动补写 SQL。`scripts/pb9-datawindow-validation/fixtures/d_external.srd` 是本包合成样例；破损列使用 `DATAWINDOW_COLUMN_DEFINITION_INVALID`，未知定义使用 `DATAWINDOW_DEFINITION_UNPARSED`。严格模式下确认列/参数/映射错误继续阻断，保留原 issue code。

复杂 SQL（含 wildcard、嵌套 SELECT、集合运算等）和部分 PBSELECT 保留 partial、`DATAWINDOW_RETRIEVE_UNPARSED` 以及未知映射，不制造 alias mismatch。完整解析后的真实 mismatch 仍阻断；partial 不掩盖已确认参数错误。修复应针对证据中的列名、类型、id 或参数，而非补写空 SQL。

| 结构与配置 | 数据库事实 | CLI / V8 |
|---|---|---|
| 默认离线 | not-run / not-requested / offline-default | 零连接；只汇总结构 |
| 合法 external + 有效显式 profile | not-run / not-applicable / external-data-no-retrieve | 结构可通过，零连接 |
| 无效显式 profile | blocked，保留配置 code | 阻断，即使 external |
| retrieve 请求未执行 | not-run，保留 provider/解析缺口原因 | 阻断 |
| 结构通过，数据库 blocked/failed | 保留全部 issue、版本、profile evidence | 阻断 |
| 离线部分解析、无确认错误 | warnings/unparsed | 默认非阻断，未完整验证 |

数据库结果追加 `databaseApplicability`、`databaseNotRunReason`、`databaseProfileConfigurationHash`；结构结果绑定 `sourceHash` 与 `validatorVersion`。V8 `objects[].dataWindowValidation` 保留分层事实，完整校验 JSON 经 evidence 引用保留。归因只在源码/快照哈希、解析完整性、校验器、profile id/内容哈希及适用性一致时比较。缺快照、partial、文件变化或配置改变为 unknown；已有问题 false 和 unknown 都不降低真实失败。

SQL Server / inline / mock profile 元数据检查与真实数据库执行分别记账。当前 CLI 未加载真实 SqlClient；SQL Server profile 未提供有效 prepare 元数据时为 not-run，显式请求被阻断。`prepare=passed/failed` 是 profile 元数据输入，不能代替数据库服务端或 PB9 检索证据。凭据通过环境引用传递，禁止写入源码、PBL 或日志。

参数类型元数据使用 inline / SQL Server 共用的有限规则：兼容、确定违反已约定声明合同、未覆盖三种结论分开。PB9 `number` 到 `int` / `decimal`、`string` 到 `nchar` 属于已覆盖兼容组合；它们不应因旧白名单遗漏而阻断。这里的兼容只表示声明类型族可绑定，未检查实际值是否超出整数范围、decimal 精度/小数位或字符长度，不保证所有值均可无损转换。具体值仍须由实际 PB9/驱动验证。

已约定的字符参数到数值 profile（如 `string` → `integer`）仍输出 `DATABASE_PARAMETER_TYPE_MISMATCH` error；这表示声明合同错误，不表示数据库永远不能转换某个字符串值。未知类型、未覆盖组合或缺少参数类型元数据输出 `DATABASE_PARAMETER_TYPE_UNVERIFIED` warning，数据库结论为 warnings，不能冒称该项已验证，也不伪造确定 mismatch。prepare 失败和 provider 未实际执行的 not-run 门禁独立保留。此返修使用 `validatorVersion=7.6.0-datawindow-2` 和数据库校验器 `7.6.0-profile-boundary-2`；缓存身份和前后归因随版本失效，不能沿用 v01 的校验结论。

V8 使用 `delivery close-loop ... --database-profile <json> [--database-profile-id <id>]` 显式请求；continue 从 preflight 恢复该选择，配置内容进入 freshness facts。显式数据库校验不复用离线缓存。逐项 check 与 blocked item 保留 `diagnosticField`，check 另保留归因和 evidence 路径。

本包 PB9 样例使用 9.0.3.8836 x86，实际加载 `pbodb90.dll` 与 32 位 ODBC Driver 17。合成 external 实际 Create、InsertRow、SetItem、GetItem 与列类型检查成立；授权测试库中的唯一合成 schema 实际参数化 Retrieve 返回预期行，缺失列负例实际返回 -1。资源创建前确认不存在，结束后按归属检查删除，既有表元数据前后摘要相同。确切版本、模块哈希、输入、运行器失败历史及清理查询见本变更 证据索引（父仓 openspec/changes/archive/2026-10-30-fix-pbbridge-7-6-0-datawindow-validation/evidence-index.md）。

复跑需在本包输出根准备新的短目录；先构建 `scripts/pb9-datawindow-validation/DataWindowNative.csproj` 的 x86 工具，以新的唯一 schema 生成合成 PBL/EXE，再调用 `Invoke-NativeDataWindow.ps1`。脚本限定既定授权目标、加密凭据引用和新结果目录；其他环境须独立授权并调整边界。不可把旧目录当作可覆盖的模板。

实际支持结论只覆盖冻结候选、合成样例及此授权测试对象；其他 PB9 驱动、PB IDE/Full Build、业务验收、正式消费项目、Toolkit Release、Git 交付和部署保持未验证或未执行。

现有 DataWindow semantic diff 对没有 retrieve 的 external 仍可能输出 `retrieve:unknown` warning；本包未将该结果称为完整语义验证。写回反导另以整个源码文本仅统一行尾后的哈希逐对象核验，目标变更及四个非目标对象均有明确数量的证据。生产流程记录的 staging 可再生二进制清理与必需证据缺失分别记账，不回填原清理路径。
