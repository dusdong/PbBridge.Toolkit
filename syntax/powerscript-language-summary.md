# PowerScript 语言摘要

本文件面向 Codex / Copilot 提供 PowerScript 文本层协作的最小背景。详细语法速查见 `skills/powerbuilder-powerscript/references/`。

当前目标主版本是 PowerBuilder 9.x。遇到 PB10+、PB12.5、PB2019、PB2021 资料时，应先按 `syntax/powerscript-pb9-compatibility.md` 判断版本边界。

## 1. 基本事实

1. PowerScript 是 PowerBuilder 的脚本语言，常见于窗口、菜单、用户对象、函数对象、DataWindow 相关对象的事件和函数中。
2. Codex 在真实项目中优先处理导出的 `.sr*` 文本，不直接编辑 `.pbl`。
3. `.sru/.srw/.srm/.srd/.sra/.srs/.srj` 的对象类型不同，但都应结合导出清单和报告理解边界。
4. PowerBuilder 旧项目常见 ANSI/GBK 编码，修改前应确认编码和换行，不要无意整体转码。

## 2. 阅读顺序

1. 先看对象头、继承关系、实例变量和全局变量。
2. 再看事件入口，例如 `open`、`clicked`、`itemchanged`、`constructor`、`destructor`。
3. 再看自定义函数和事务相关公共函数。
4. 最后结合 `manifest.json`、`verify.json`、`report.md` 确认对象范围、异常和导出证据。

## 3. 语义注意

1. `//` 和 `/* ... */` 是注释。
2. `if / elseif / else / end if`、`choose case / end choose`、`for / next`、`do / loop` 是常见控制结构。
3. PowerBuilder 事件、对象生命周期、DataWindow 缓冲区和事务对象不能按 C# 或 JavaScript 习惯直接类比。
4. `null`、空字符串、数值零和 DataWindow 未命中状态要分开判断。
5. 迁移前先说明源语义，再设计目标实现，不做逐行机械翻译。

## 4. 高频风险

1. 改错事件入口导致 UI 行为变化。
2. 漏掉 `SQLCA.SQLCode` 检查、`rollback` 和提前返回路径。
3. 把 DataWindow 行列状态、过滤、删除缓冲区和更新行为简化成普通表格。
4. 改动共享函数或全局变量后没有扩大检索调用点。
5. 只看单个 `.sr*`，没有结合 manifest 和 report 判断影响范围。
