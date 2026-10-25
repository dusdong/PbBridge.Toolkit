# PowerScript 工作示例

## 示例一：阅读 `.sru/.srw`

目标：快速判断对象职责、入口函数和风险点。

步骤：

1. 先读文件头部的 `forward` 与 `global type`，确认对象类型和继承关系。
2. 读 `type variables`，记录对象持有的服务、状态、DataStore、窗口控件引用。
3. 读 `forward prototypes`，把 `public function` 按业务动作分组，例如读取、保存、查询、退款、连接。
4. 读 `event constructor/open/destructor/close`，确认初始化与释放路径。
5. 只在必要时进入函数体，优先看 SQL、网络调用、`ref` 输出、`commit/rollback`。

输出建议：

```text
对象职责：...
关键入口：of_xxx / ue_xxx
状态依赖：gnv_config / gnv_app / SQLCA / DataStore
风险点：事务边界、对象释放、编码、UI 阻塞
```

## 示例二：审查事务代码

目标：找出数据不一致、吞错、提前返回未回滚等问题。

审查顺序：

1. 找到所有内嵌 SQL：`select`、`insert`、`update`、`delete`。
2. 每条写 SQL 后检查 `sqlca.sqlcode`。
3. 失败路径必须有错误记录和 `rollback`。
4. 成功路径只能在所有写入完成后 `commit`。
5. 如果存在“先删后插”，确认保留旧订单状态、流水号、下单标记等业务字段。

典型风险：

```powerscript
delete from OrderItem where OrderId = :ls_id;
insert into OrderItem(...) values(...);
commit;
```

如果 `insert` 失败但没有 `rollback`，订单明细可能被清空。审查时要沿所有 `return -1` 分支确认事务处理。

## 示例三：迁移到 C# / Avalonia

目标：保留 PowerScript 行为语义，而不是逐行翻译。

迁移步骤：

1. 先识别 UI 事件、服务对象、数据库访问和全局状态。
2. 将 `global type` / `type variables` 映射为 C# 类和字段。
3. 将 `public function` 映射为服务方法，保留 `ref` 参数表达的多返回值语义。
4. 将 SQLCA 事务映射为仓储或 Unit of Work。
5. 将窗口控件事件映射为 ViewModel 命令或事件处理器。

映射示例：

```text
PowerScript nvo_x.of_save(ref string as_message)
=> C# SaveResult Save(...)

PowerScript event clicked
=> Avalonia ICommand / async event handler

PowerScript commit / rollback
=> transaction.Commit() / transaction.Rollback()
```

迁移输出应包含：

- 源对象职责说明。
- 目标 C# 类型划分。
- 数据流和事务边界。
- 与旧行为不同的地方。
- 需要人工确认的业务规则。
