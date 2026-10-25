# PowerBuilder 项目约定

## 本项目资料边界

PowerScript 资料由本项目自持：

- 手册产物：`docs/reference/powerscript/manual/`
- 原始来源：`docs/reference/powerscript/source/`
- 生成校验工具：`docs/reference/powerscript/tools/powerscript-manual/`
- Codex 技能入口：`.codex/skills/powerbuilder-powerscript/`

不得在日常任务中依赖外部历史仓库；本项目内资料才是维护边界。

## 编码约束

PowerBuilder 旧源码和 SQL 脚本可能是 ANSI/GBK。修改前应确认编码；如果只是阅读，终端显示乱码不等于文件内容损坏。

处理原则：

- 小范围修改优先保持原编码。
- 不做无关格式化。
- 不批量重写 `.sru/.srw`。
- 不把 PB 导出文件自动转码，除非任务明确要求并已有回归策略。

## 阅读 `.sru/.srw`

优先看这些区域：

- `forward`：类型和控件前置声明。
- `global type`：对象继承、属性、事件类型。
- `type variables`：实例变量和状态。
- `forward prototypes`：公开函数列表，适合快速理解对象能力。
- `event ... end event`：窗口、控件、用户对象主要交互逻辑。
- `on object.create/destroy`：控件创建销毁和对象生命周期。

## 审查重点

- 事务：`SQLCA.SQLCode`、`commit`、`rollback` 是否成对合理。
- 资源：`create` 后是否在析构或关闭路径 `destroy`。
- UI：事件中长耗时逻辑是否调用 `Yield()`，是否可能阻塞界面。
- 网络：HTTP/WebService 调用是否处理超时、错误文本、认证 Token。
- JSON：字段名大小写、数组下标、`ref` 输出对象是否保持一致。

## 迁移到 Avalonia / .NET

迁移前先把 PowerScript 行为讲清楚：

- 哪些是 UI 事件。
- 哪些是服务对象状态。
- 哪些依赖全局对象。
- 哪些 SQL 写入必须保持事务边界。
- 哪些 DataWindow/DataStore 行为需要映射为数据模型、仓储或视图模型。

不要逐行翻译。先按职责拆分为模型、服务、仓储、视图模型和 UI 交互。
