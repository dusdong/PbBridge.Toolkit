# DataWindow 数据库校验指南

默认 `datawindow validate` 和 V8 delivery 只执行离线结构校验，不连接数据库。

PBSELECT 查询列按原始顺序读取 `COLUMN(NAME=...)` 和 `COMPUTE(NAME=...)`，支持计算表达式的显式及隐式别名。展示层 `compute(...)` 控件不属于查询列。无法完整解析的投影输出 `DATAWINDOW_RETRIEVE_UNPARSED`，不能把解析遗漏解释为业务 dbname 错误；完整解析后确认的不匹配仍按 strict 策略阻断。

V8 DataWindow 预检用同一校验器比较当前源码和目标 PBL 导出快照，分别保留完整结果。`scope=target` 只表示目标范围；`relatedToCurrentChange` 的 `false` 表示该诊断在可信基线中已存在，`true` 表示新增或加重，`unknown` 表示缺少可比较证据。归因不豁免阻断，不代替 PB9 编译或运行验收。同一规则在不同字段上的问题分别保留。

显式启用数据库语义校验：

```powershell
pbbridge datawindow profile init --provider sqlserver --project-root . --profile-id dev
pbbridge datawindow validate src/app/d_orders.srd --database-validation --database-profile .pbbridge/database-profiles.json --database-profile-id dev
```

profile 中可以包含 provider、server、database、schema、userId、密码环境变量、连接串环境变量、`connectionTimeoutSeconds`、`commandTimeoutSeconds` 和 `readOnlyIntent=true`。结果只输出脱敏 evidence，不输出 password、uid/pwd、token 或完整连接串。

当前版本支持 SQL Server profile 与 inline/mock profile 元数据，用于校验表、字段、prepare 开关和参数基础类型。复杂 PBSELECT 会输出 `dataWindowRiskLevel=low|medium|high|unknown`，不得把无法证明的语义直接判定为通过。生成向导只写 `.pbbridge/database-profiles.example.json` 示例，默认用环境变量保存密码。

7.6.0 追加 `sourceDefinitionKind`、`parseCompleteness`、`classificationEvidence[]`、`populationUsage`。完整合法 external 校验列名、PB9 类型和视觉 id/名称绑定，不要求 SQL；空 SQL 或调用方声明不足以证明合法 external。没有可信调用上下文时用法为 unknown。部分 SQL/PBSELECT 的映射保持 unknown，确认参数和列错误仍按 strict 阻断。

默认零连接。显式 profile 先检查有效性；合法 external 为 `databaseValidationVerdict=not-run`、`databaseApplicability=not-applicable`、`databaseNotRunReason=external-data-no-retrieve`，仍零连接。retrieve 显式请求未完成、blocked 或 failed 必须阻断 CLI 与 V8。当前 CLI 未加载真实 SqlClient，未执行的 prepare 为 not-run；profile 的 prepare 开关与 inline/mock 元数据通过不能代替实际数据库或 PB9 Retrieve。

结果绑定源码哈希、校验器版本、profile id/配置内容哈希及适用性。V8 `objects[].dataWindowValidation` 保留分层结论与完整 evidence 引用；基线 partial、缺快照或配置改变时归因为 unknown。false/unknown 归因不降低失败。选定 PB9 x86 样例和实际驱动支持范围以确切候选证据为准，不推广为全驱动或业务验收。

inline 和 SQL Server 共用有限的参数声明规则。`number` → `int` / `decimal` 和 `string` → `nchar` 为已覆盖兼容组合；数值范围、精度、小数位、长度和具体值转换仍未静态证明。已约定的 `string` → `integer` 等字符到数值声明错误保留 `DATABASE_PARAMETER_TYPE_MISMATCH` error；未知类型、缺少类型或未覆盖组合为 `DATABASE_PARAMETER_TYPE_UNVERIFIED` warning，不能声称已验证或确定不兼容。prepare 失败与实际 provider 未执行的 not-run 阻断独立保留。校验器身份为 `7.6.0-datawindow-2` / `7.6.0-profile-boundary-2`，旧缓存和不可比的旧版本诊断不复用。
