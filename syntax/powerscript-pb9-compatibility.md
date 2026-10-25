# PowerScript PB9 兼容性摘要

本文件用于约束 Codex 在 PB9 项目中的 PowerScript 判断。它整理自本 toolkit 的 PB9 定位、PB Classic 12.5 手册来源风险，以及 Appeon PB2019/PB2021 中 “PowerBuilder 9 or earlier” 升级/迁移主题。

## 1. 版本定位

1. 当前目标主版本是 PowerBuilder 9.x。
2. PB Classic 12.5 PowerScript 手册可用于理解通用语言结构，但不是 PB9 支持矩阵。
3. PB2019/PB2021 升级文档用于识别迁移风险，不用于直接证明 PB9 支持新特性。
4. 无法确认 PB9 支持的 API、对象、属性、事件和运行时行为，应标为版本敏感。

## 2. 重点风险

1. Unicode 和编码：PB10 起 Unicode 变化会影响字符串、文件、外部函数和 XML；PB9 旧项目常见 ANSI/DBCS/GBK。
2. DBCS 和中文界面：控件文本、字体、DataWindow 标签和对象属性需要在真实 locale 下确认。
3. DataWindow：重点检查 `ImportFile`、edit mask、WMF 保存和字符串日期转换。
4. 外部函数和 DLL：PB10+ 自动迁移行为不应直接套回 PB9。
5. 旧版本脚本行为：保留字、`SystemError`、`IsValid`、`OpenSheet`、DataWindow 滚动事件和 ListView/TreeView 事件都可能影响旧项目。
6. 事务和中间件：EAServer、MTS/COM+ 相关异常和部署行为只有在项目实际涉及时才进入审查。
7. Web/JSP：旧 Web/JSP 目标属于专项迁移，不应和普通桌面对象修改混同。

## 3. 排除或降级主题

1. Toolbar/Icon changes 不进入 PowerScript 主资料。
2. EAServer 6 平台升级不进入普通桌面项目主线。
3. EJB client 不进入普通 PowerScript 主线。
4. Web/JSP、EAServer、MTS/COM+ 只在源码实际涉及时作为条件适用资料。

## 4. Codex 判断规则

1. 对 PB9 项目给建议时，优先引用 manifest 中 `libraries[].sourceRoot` 指向的 `.sr*`，以及 artifacts 状态目录中的 `manifest.json`、`verify.json` 和 `report.md`。
2. 引用后续版本文档时，只能说“迁移风险提示”，不能说“PB9 一定支持”。
3. 需要 PB9 IDE 编译或运行验证的点，应在最终输出中单独列出。
