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
