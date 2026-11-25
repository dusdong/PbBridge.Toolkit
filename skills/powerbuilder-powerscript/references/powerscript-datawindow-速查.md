# DataWindow / DataStore 审查速查

以 Sybase PowerBuilder 9 桌面项目为基线。从 `.srd` 和调用脚本确认数据源、对象类型以及事务由谁管理。

## 编辑校验与行状态

- 在保存入口确认 DataWindow 控件的当前编辑值已通过校验。`AcceptText()` 返回 `1` 表示成功，返回 `-1` 时应停止保存。`ItemChanged` 的 `data` 是待接受的编辑文本，`GetItem*` 读取缓冲区中已有的值。避免在 `ItemChanged` 调用会自动执行 `AcceptText()` 的 `Update()`。

| 事件 | 返回码 |
| --- | --- |
| `ItemChanged` | `0` 接受，`1` 拒绝并保留焦点，`2` 拒绝并允许焦点移动 |
| `ItemError` | `0` 拒绝并显示默认错误，`1` 拒绝且省略默认提示，`2` 接受，`3` 拒绝并允许焦点移动 |
| 窗口 `CloseQuery` | `1` 取消关闭，`0` 允许关闭。关闭前需要保存时，沿用保存入口的校验与结果 |

- 用 `GetItemStatus` 核对指定缓冲区的行、列状态。Primary 和 Filter 中，`New!` 表示未修改的新行，`NewModified!` 对应 INSERT。对于已检索的 `DataModified!` 行，只修改可更新的非键列时生成 UPDATE。Delete 中已存在于数据库的行可生成 DELETE。
- 核对生成的 SQL 时，先看 `.srd` 的更新表、键列和可更新列。修改 DataWindow 定义的唯一键列时，`updatekeyinplace=yes` 生成 UPDATE，`updatekeyinplace=no` 先生成 DELETE 再生成 INSERT。`UpdateWhere` 控制 UPDATE 和 DELETE 的 WHERE 条件。 [Sybase 键列修改规则](https://infocenter-archive.sybase.com/help/topic/com.sybase.dc00844_1150/html/pbug/BHBCHGBI.htm)

## 取数和保存事务

- SQL 数据源的 `Retrieve()` 返回检索行数，`0` 表示结果为空，`-1` 表示失败。已绑定 DataWindow 对象的 `Update()` 返回 `1` 表示成功，返回 `-1` 表示失败。数据库错误可从 `DBError` 取诊断。External 数据源按列定义和 `InsertRow`、`SetItem` 等实际填充路径审查。
- `SetTrans()` 由 DataWindow 管理内部连接、提交和回滚。`SetTransObject()` 使用应用提供的事务对象，要沿调用链查找连接、`AutoCommit` 和事务收尾。运行时更换 `DataObject` 后检查事务绑定。
- 多个 DataWindow 或 DataStore 共用一个应用事务且 `AutoCommit = FALSE` 时，按以下顺序审查主从保存。

  1. 先校验各控件的当前编辑值。已成功执行 `AcceptText()` 的控件可用 `Update(FALSE, FALSE)`。由 `Update()` 接收编辑值时用 `Update(TRUE, FALSE)`。第二个参数为 `FALSE` 时保留更新标志。
  2. 逐个检查 `Update()` 的结果。任一更新失败时，由事务所有者用同一事务对象回滚。全部更新成功后统一 `COMMIT`，检查该事务对象的 `SQLCode`。
  3. 确认提交成功后，对本次以 `resetflag = FALSE` 更新的每个 DataWindow 或 DataStore 分别调用 `ResetUpdate()`。若只重置主表，明细新增行会保留更新标志，下次保存时可能再次发送 INSERT。更新或提交失败时保留各对象的标志，按项目的错误处理流程决定如何重试。 [Sybase ResetUpdate 说明](https://infocenter-archive.sybase.com/help/topic/com.sybase.dc37783_1150/html/dwref/BABBFIGC.htm)

## 在目标工程复核

- 查 `DBParm` 时以目标 PB 版本、`Transaction.DBMS`、驱动版本和实际位数定位对应的连接参考，再核对参数的可用性和默认值。
- `pb_check.py` 等文本检查器的结果由人工复核。遇到事务告警时，沿调用链确认 DataWindow 的绑定方式、真实执行的 SQL 和收尾所用的事务对象。
- 只读审查时，根据对象定义和调用脚本说明行为。修改业务行为后，由用户在目标 PB IDE 编译，并按改动选择验证场景。涉及数据库读写时，在目标驱动上核对执行结果。
  - 修改编辑校验时，检查最后一个单元格仍在编辑时直接保存，以及输入校验失败时的处理。
  - 修改内存 DataStore 的填充逻辑时，核对填充后的列值和行状态。
  - 修改共享事务时，验证主从表提交后直接再次保存会跳过已提交的行，以及中途失败时能否回滚并重试。

## 参考依据

- 事务归属、编辑校验及行状态见 PB9 安装帮助 `pbman90.chm` 的 DataWindow Programmer's Guide。`CloseQuery` 可对照 Application Techniques 的窗口关闭示例及仓库的 PB9 导出样例。
- 事件返回码和方法参数可对照 Sybase 11.5 的对应条目，并在目标 PB 版本确认项目用法。 [ItemChanged](https://infocenter-archive.sybase.com/help/topic/com.sybase.dc37783_1150/html/dwref/dweCAIEBFFC.htm) · [ItemError](https://infocenter-archive.sybase.com/help/topic/com.sybase.dc37783_1150/html/dwref/CAIBFEJG.htm) · [AcceptText](https://infocenter-archive.sybase.com/help/topic/com.sybase.dc37783_1150/html/dwref/CAIDFCBI.htm) · [Update](https://infocenter-archive.sybase.com/help/topic/com.sybase.dc37783_1150/html/dwref/CAIEBDAJ.htm)
