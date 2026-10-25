# PowerScript PB9 兼容边界

当前项目的 PowerBuilder 工作环境按 PB9.x 理解。已整理的 PowerScript 全文手册主要来自 PB Classic 12.5，因此只能作为语言参考，不能作为 PB9 支持矩阵的最终依据。

## 默认规则

1. 生成、修改、审查 PowerScript 时，默认目标版本是 PB9.x。
2. 如果资料来自 PB10、PB12.5、PB2019、PB2021，应先判断是否只是迁移说明。
3. 不能确认 PB9 支持的函数、对象、属性、事件和运行时行为，应标为版本敏感。
4. 最终可运行性仍以 PB9 IDE 编译、调试和业务验收为准。

## 来自 Appeon 升级文档的重点风险

1. Unicode：PB10 起源码和运行时进入 Unicode 时代，PB9 旧项目常见 ANSI/DBCS/GBK。
2. 外部函数：PB10+ 迁移会调整字符串、字符、结构相关外部函数声明；PB9 代码不要直接套用升级后的声明。
3. DBCS：中文对象属性、字体、控件文本和 DataWindow 标签需要按 locale 和字体验证。
4. DataWindow：`ImportFile` 大文件、WMF 保存、edit mask 正负号输入都存在版本差异或修复历史。
5. 日期：PB10+ `Date(string)` 部分匹配行为可能造成年份误判；PB9 迁移时要检索字符串转日期代码。
6. 旧版本脚本行为：保留字、`SystemError`、`IsValid`、`OpenSheet`、DataWindow 滚动事件和 ListView/TreeView 事件都可能影响从更老版本演进到 PB9 的代码。

## 排除或降级主题

1. Toolbar/Icon changes：不进入 PowerScript 主资料。
2. EAServer 6：平台升级专项，不进入普通桌面项目主线。
3. EJB client：Java/EJB 集成专项，不进入普通 PowerScript 主线。
4. Web/JSP、EAServer、MTS/COM+：只有项目源码实际涉及时才作为条件适用资料。

## Codex 输出要求

遇到版本敏感点时，输出中应明确写出：

1. 依据来自 PB9 项目源码、Toolkit 导出报告，还是后续版本迁移文档。
2. 是否需要 PB9 IDE 验证。
3. 是否可能影响编码、事务、DataWindow、外部 DLL、COM/EAServer 或 Web/JSP。

## 参考资料

- `docs/reference/powerbuilder-pb9-upgrade/appeon-pb9-or-earlier-upgrade.md`
- Appeon PB2021：`Upgrading from PowerBuilder 9 or earlier`
- Appeon PB2019：`Migrating from PowerBuilder 9 or earlier`
