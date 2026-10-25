# PowerScript PB9 反例

这些示例用于提醒 Codex 不要把现代语言、PB10+ 或其他平台习惯套进 PB9 项目。遇到不确定点时，标为版本敏感并交给 PB9 IDE 验证。

## 函数签名

不要只改大小写或参数名来制造“重载”。PB9 项目中应保持既有函数签名和调用点一致，尤其是全局函数、nvo 公共函数和外部调用入口。

## DataWindow 事件

不要假定 DataWindow 事件行号、缓冲区和当前行在不同版本中行为完全一致。改 `ItemChanged`、`Clicked`、`RetrieveEnd` 等事件时，必须检查返回值语义和现有错误处理。

## 外部函数

不要直接套用 PB10+ Unicode 外部函数声明。PB9 旧项目常见 ANSI/DBCS/GBK，字符串、char、结构体和 DLL 入口必须按项目现有声明处理。

## ANSI/DBCS

不要无意把旧 `.sr*` 从 ANSI/GBK 改成 UTF-8 后再导入 PBL。涉及中文控件文本、DataWindow 标签、外部 DLL 字符串时，必须保持项目编码策略。

## 事务对象

不要在提前返回路径漏掉 `rollback`，也不要在局部函数中随意 `commit` 全局 `SQLCA`。审查时必须跟踪 `SQLCA.SQLCode`、`f_trap_sqlca()`、错误消息和调用方事务边界。

## `ref` 参数

不要把 `ref` 参数当作普通值传递。迁移或重构时要确认调用方是否依赖输出值、数组内容或对象引用被原地修改。
