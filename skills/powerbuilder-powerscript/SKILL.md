---
name: powerbuilder-powerscript
description: Use when reading, explaining, writing, reviewing, refactoring, or migrating PowerBuilder/PowerScript code, especially files such as .sru, .srw, .sra, .srd, .srm, .srs, .srj, PBL exports, DataWindow/DataStore code, SQLCA transaction code, PowerBuilder events, or PowerScript syntax questions.
---

# PowerBuilder / PowerScript

使用本技能处理 PowerBuilder 与 PowerScript 代码。优先保持旧工程风格，避免把 C#、JavaScript 或现代 Basic 习惯误套到 PowerScript。

先确认实际 workspace 的 PowerBuilder 版本。PowerScript 全文手册主要来自 PB Classic 12.5，只能作为语言参考；对无法确认目标版本支持的 API、属性、对象和运行时行为标明需在目标版本验证。

## 使用流程

1. 先判断任务类型：
   - 判断 PB9 版本、Unicode/DBCS 或旧中间件迁移的兼容性时，读 `references/powerscript-pb9-兼容边界.md`。
   - 涉及 DataWindow/DataStore 的编辑校验、行状态或保存事务时，读 [DataWindow / DataStore 审查速查](references/powerscript-datawindow-速查.md)。
   - 语法、声明、事件、对象生命周期：读 `references/powerscript-速查.md`。
   - 保留字、运算符、声明参数、函数名：读对应 `references/powerscript-*.md`。
   - 本项目工程习惯、编码和迁移注意事项：读 `references/powerbuilder-项目约定.md`。
2. 外部项目可直接使用本技能附带的 `references/`。只有在维护 `Powerbuilder.IDE` 父仓且需要完整上下文时，才在父仓根目录查阅：
   - `docs/reference/powerscript/manual/手法手册.md`
   - `docs/reference/powerscript/manual/附录-表格全集.md`
3. 修改 `.sru`、`.srw` 或 `.srd` 前，先确认并保留源文件编码。PowerBuilder 旧源码常见 ANSI/GBK。
4. 审查内嵌 SQL 时，检查实际事务对象的 `SQLCode`、`COMMIT`、`ROLLBACK`、错误消息和提前返回路径。按项目约定检查 `f_trap_sqlca()` 等错误处理。
5. 迁移到 C# / Avalonia 时，先解释源 PowerScript 语义，再设计目标实现；不要逐行机械翻译事件、全局对象和 DataWindow 行为。

## 资料索引

- `references/powerscript-速查.md`：高频语法和代码阅读指南。
- `references/powerscript-示例.md`：真实工作场景示例，包括源码阅读、事务审查、迁移说明。
- `references/powerscript-pb9-兼容边界.md`：PB9 目标环境和 PB10+ 升级风险边界。
- `references/powerbuilder-项目约定.md`：本项目处理 PowerBuilder 资料和源码的约定。
- `references/powerscript-保留字.md`：PowerScript 保留字。
- `references/powerscript-运算符.md`：运算符与优先级。
- `references/powerscript-声明速查.md`：变量、实例变量、常量、数组声明参数。
- `references/powerscript-常用函数索引.md`：函数标题索引。
- `references/powerscript-表格全集.md`：结构化表格全集。

## 校验命令

以下命令仅在 `Powerbuilder.IDE` 父仓根目录运行，需要 npm 及父仓自带的手册校验工具。

```bash
npm --prefix docs/reference/powerscript/tools/powerscript-manual run validate
```
