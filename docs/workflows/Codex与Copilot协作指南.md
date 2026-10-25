> 本文档由 `PbBridge.Toolkit` 从父仓库手册同步生成。
> 当前 toolkit 固定提供 `CLI win-x86 + IDE win-x64` 的 Windows 运行时组合；正式写回支持矩阵仍以父仓库事实源为准。
# Codex 与 GitHub Copilot 协作指南

本文档回答两个问题：

1. **面对一个真实的 PowerBuilder 项目，例如 `G:\Langchao\国润铜业`，应该如何借助 `PbBridge.Cli` 与 Codex / GitHub Copilot 配合使用？**
2. **站在 Codex / GitHub Copilot 的使用视角，本系统的功能现在是否齐全？**

先说结论：

> 当前系统已经**基本齐备**作为 **PowerBuilder 9.x 辅助开发工具 + AI 协作前置层** 所需的关键能力；
> 并且已经补齐了面向真实项目试点的自动写回硬失败准入、最小权限策略和认证模式；
> 但它**仍不应被表述为**已经完成产品化的、可在所有真实项目上稳定自动写回的成熟双向桥接平台。

对最终使用者来说，可以把问题理解成一句话：

> **Codex 不能直接可靠读取 `.pbl`，所以先用 `PbBridge.Cli` 把 PowerBuilder 项目转换成 Codex 可处理的文本工作区，再让 Codex 在文本层参与编码。**

## 1. 协作定位

当前 Windows 环境不支持 Codex 操控 PowerBuilder IDE。Codex 使用 CLI、项目脚本和文件操作完成已授权工作，不通过桌面自动化、UIA、SendKeys、鼠标坐标或临时脚本操作 PB IDE，不寻找 GUI 替代工具或自动终止 IDE 进程。此边界不限制 Toolkit 已支持且获得授权的 CLI 写回。

Regenerate、Full Build、Painter、调试与业务运行验收由用户完成。不主动扫描或检查 PB90/PB IDE 是否运行，不把进程存在或“已关闭”回复设为预检、写回的前置条件，也不为此询问许可。由 CLI 的实际文件锁、目标快照、冲突与恢复结果判断能否继续；确有阻断时报告具体对象、原因和所需操作，不自动关闭或终止 IDE 进程。

用户已授权当前任务的源码修改和受控写回时，明确的源码语法/编译错误可自行做最小修复、重新预检，并在门禁通过后继续，无需逐次确认。即使 CLI 将此类错误标为 `manual-action`，也先结合诊断、reason code 和实际所需动作判断；该标签本身不撤销既有授权。修复后使用新预检结果及其可信依赖计划继续；核对已有成功对象与当前目标事实，避免重复写入。每次重试必须有源码、依赖或环境事实变化；同一原因在没有新修复依据时仍失败，应报告阻断，禁止原样循环 Apply。源码修正、预检通过、实际写入和 IDE 验收分别汇报，累计写入只计实际成功结果。

只有实际需要 PB IDE 操作、人工验收、用户决策或无法在授权范围内解决的阻断，才完成其余独立工作后生成 checklist/handoff，列明 workspace/PBW、PBL/对象、session、原因、人工步骤与所需证据，并暂停依赖步骤。`manual-action` 或 `ide-fallback-required` 的人工动作说明不得拼成命令执行，也不得通过修改结果 JSON、跳过门禁或伪造证据继续。未验收项保持 `not-checked`，已有失败或阻断继续保留。收到结果后从现有有效 session 继续，过期时重新预检，不为补证据重复 Apply；人工确认记为 `attested`，不能冒充 `verified`。

本系统最适合承担的是“**把 PB9 资产转换为 AI 可理解、可校验、可审查的文本工作区**”这一层。

建议这样分工：

- **PB Bridge / SharpIDE / CLI**：负责导出、索引、校验、差异、报告、宿主浏览与运行态诊断
- **GitHub Copilot**：负责当前文件理解、局部改写、注释与脚本生成、日常交互式问答
- **Codex**：负责跨文件整理、批量修改、结构化任务执行、文档与规则收口
- **人工审查者**：负责确认业务意图、批准变更、决定是否进入导入/回写链路

换句话说：

> 不要让 AI 直接对 `.pbl` 做“黑盒猜测”；
> 应先把 PB9 工作区导出为 `.sr*` 文本，再让 Codex / Copilot 在文本层工作。

## 2. 面向真实项目的最小落地场景

如果你的目标是：

- 项目目录在 `G:\Langchao\国润铜业`
- 项目本身是 PowerBuilder 开发
- 你想让 Codex 参与理解、修改、整理和生成代码相关产物

那么最准确的做法不是“让 Codex 直接读取 `.pbl`”，而是：

1. 先定位该项目实际使用的 `.pbw` 文件
2. 用 `PbBridge.Cli` 执行 `export`
3. 让导出结果生成 `.sr*` 文本和 `manifest.json`
4. 让 Codex 基于这些文本产物进行分析和编码
5. 再用 `verify / report / diff` 把修改结果变成可审查证据

可以把它理解为：

> **PbBridge.Cli 负责“翻译与取证”，Codex 负责“理解与编码”，人工负责“批准与回写决策”。**

## 3. 推荐工作流

最推荐的协作路径是：

1. **Export**：把 `.pbw` / `.pbl` 导出成 `.sr*` 文本和 `manifest.json`
2. **AI**：让 Copilot / Codex 在文本层做理解、整理、候选修改与说明生成
3. **Verify**：运行 `verify`，检查质量、结构和规则问题
4. **Review**：运行 `diff` / `report`，人工审查结果
5. **Import（谨慎）**：只有在明确知道边界和风险时，才进入 `plan-import` / `import` / `rollback`

一句话记忆：

> **Export → AI → Verify → Review**

这是当前最稳妥、也最符合本仓库实际成熟度的使用方式。

### 3.1 对 `G:\Langchao\国润铜业` 这类项目的具体理解

如果你面对的是一个传统 PowerBuilder 项目，建议按下面的口径向使用者说明：

- `PbBridge.Cli` 不是替代 Codex，而是给 Codex 准备输入面
- Codex 不直接面向 `.pbl` 编码，而是面向导出的 `.sr*`、`manifest.json`、`verify`、`report` 结果工作
- 如果没有先导出，Codex 对项目结构、对象边界、成员信息和差异证据的理解都会明显不足

### 3.2 一个更贴近用户提问的表述

下面这句话适合直接放在说明文案、skill 或协作手册里：

> 对于 `G:\Langchao\国润铜业` 这类 PowerBuilder 项目，Codex 不能直接可靠读取 `.pbl` 内部对象；正确做法是先通过 `PbBridge.Cli` 将 `.pbw/.pbl` 导出为 `.sr*` 文本和结构化清单，再让 Codex 在导出工作区上执行理解、改写、校验辅助和文档生成任务。

## 4. Copilot 与 Codex 分别适合做什么

### 4.1 GitHub Copilot 更适合

- 解释当前打开的 `.sr*` 对象源码
- 帮你理解某个窗口、菜单、user object 或 function object 的结构
- 生成局部注释、说明文字、修复建议
- 为当前仓库生成 PowerShell / C# / Markdown 辅助内容
- 对 `verify` 结果做逐条解释与建议

### 4.2 Codex 更适合

- 跨多个导出文件做一致性整理
- 批量收口文档、规则和任务说明
- 对 manifest / verify / diff / report 结果做系统化分析
- 生成“变更候选 + 审查结论 + 后续建议”一整套产物
- 在文本工作区上执行明确约束的多文件任务

### 4.3 本系统当前最适合提供给 AI 的证据

- `src/.../*.sr*`：PB 导出文本源码
- 根 `manifest.json`：对象元数据、成员元数据、质量元数据
- `verify` 输出：规则问题、行号、证据片段、阻断语义
- `diff` 输出：对象级与成员级变化
- `report.md`：面向人工和 AI 的聚合摘要
- SharpIDE 浏览树 / 问题面板：辅助人工浏览和确认

## 5. 从 Codex / Copilot 视角看，哪些能力已经齐全

下列能力可以认为已经**基本齐全**，足以支撑“PB9 辅助开发工具 + AI 协作前置层”的定位。

### 5.1 AI 可读导出能力

系统已经能把 `.pbw` / `.pbl` 转为 AI 更容易处理的 `.sr*` 文本与 `manifest.json`，并保留：

- 对象路径
- 对象类型
- 成员级签名与哈希
- 导出保真度和成员化模式

这一步非常关键，因为它把 PB9 的二进制/宿主内资产，变成了 Codex / Copilot 可直接处理的工作区文本。

### 5.2 校验与证据链能力

系统已经具备成熟的 `verify` / `diff` / `report` 主路径，并已形成：

- 规则编号
- 严重级别
- 定位信息
- evidence 片段
- 面向人工的 Markdown 汇总

这意味着 AI 的建议不再是“口头猜测”，而可以绑定到真实证据。

### 5.3 SharpIDE 宿主浏览能力

系统已经能在 SharpIDE 中：

- 打开 `.pbw`
- 展开 `.pbw -> .pbt -> .pbl -> type -> object`
- 打开对象源码
- 执行 verify / report
- 在问题面板中消费结果

这让“AI 建议 + 人工确认”的工作流有了宿主侧落点。

### 5.4 自动化入口和基线

当前仓库已经有较稳定的验证入口：

- `Validate Workspace`
- `PB Bridge Quick Check`
- `PB Bridge Full Baseline`
- `SharpIDE Smoke Prep`
- `Export PB90 Sample`
- `doctor` / `list-rules` / `version`

再加上现有测试和集成测试基线，足以支撑“协作前先自检、协作后再复核”的日常工作流。

## 6. 哪些能力已有，但仍偏早期或原型

下面这些能力**存在**，但还不应被当作成熟承诺：

- `plan-import`
- `resolve-import-conflicts`
- `import`
- `rollback`
- Windows x86 + PBSpy 写回路径
- ORCA / PBSpy 多适配器写回消费链路

这些能力当前更适合这样理解：

- 可做内部验证
- 可做链路预演
- 可辅助审查回写风险
- 可支持原型阶段试验

而不是：

- 默认适合对真实生产 PB9 项目自动批量写回
- 已具备成熟冲突治理和全量审计保障
- 可以在缺乏人工批准时独立承担回写责任

## 7. 站在 AI 协作视角，当前还不齐全的部分

如果从 Codex / Copilot 的“长期高效协作体验”来审视，本系统仍有一些明显缺口。

### 7.1 实时反馈不够强

当前更偏向“批处理式验证”：

- AI 修改文本
- 用户手工触发 `verify`
- 再查看结果

这已经可用，但还不是“边改边给反馈”的成熟体验。

### 7.2 写回安全性还不足以产品化承诺

尽管回写原型已经存在，但仍不建议把它表述为：

- 全面成熟
- 适用于所有真实项目
- 可在缺少人工审查时自动执行

### 7.3 平台与版本边界仍需清晰提示

当前最稳妥的边界仍是：

- **目标主版本：PB9**
- Windows x86 更适合验证 PBSpy 写回链路
- macOS 当前更适合只读分析与宿主使用
- 多版本混用与更广泛产品化支持仍不是当前主承诺

### 7.4 面向 LLM 的轻量摘要层仍可继续增强

虽然 `manifest.json` 与 `report.md` 已经很好用，但如果未来希望更高频地服务 Codex / Copilot，仍可以继续补：

- 更轻量的 summary 产物
- 更聚焦的对象级 / 成员级导航摘要
- 更直接的依赖链查询能力
- 更即时的验证消费层

这些不是“没有就不能用”，而是“用了还可以更顺手”。

> **当前执行口径（2026-04-20）**：这部分增强已进入独立的 `pb-p4-ai-collaboration-experience` change。P4 的目标是补“更轻量的摘要与导航层”，不是替代 `verify / diff / report` 的正式审阅地位；当前最稳妥的事实源仍然是完整 `report.md`、结构化 `verify/diff` 结果以及宿主内可见证据。

## 8. 最准确的齐全度结论

### 8.1 对“PowerBuilder 9.x 辅助开发工具”这个目标

**结论：当前已经基本齐全。**

原因是系统已经稳定覆盖了以下关键需求：

- 把 `.pbl` 转为 AI 可读文本
- 对文本产物做验证、差异、报告
- 在宿主里浏览和消费结果
- 为 Codex / Copilot 提供结构化证据来源

这已经足以支撑：

- 代码理解
- 规则审查
- 差异解释
- 文档整理
- 文本层候选修改
- 人工审查辅助

### 8.2 对“成熟的生产级双向桥接层”这个目标

**结论：当前还不齐全。**

原因是下面这些要素还没有全部达到“成熟产品级”口径：

- 全面稳定的写回保障
- 更强的冲突治理与交互式引导
- 更完整的权限与审计消费层
- 更实时的反馈循环
- 更广泛的真实项目长期验证

### 8.3 对“让 Codex 对真实 PB 项目做成熟、稳定、低风险的自动写回”这个目标

**结论：当前已具备生产强化后的受控闭环，但还不能对所有真实项目做成熟承诺。**

更准确地说：

- 当前已经足够支撑 Codex 参与真实 PB 项目的文本层编码
- 当前已经具备受门禁控制的 `autonomous-writeback` 闭环
- 当前还不足以支撑 Codex 在所有真实 PB 项目上做成熟、稳定、低风险的默认自动写回

当前已经补齐的闭环能力包括：

- 自动模式统一门禁
- 工作区级准入策略与对象范围 allowlist
- 缺少基线证据时的硬失败策略生成
- 最小权限白名单默认收紧
- v4 `import-object / import-objects / import source` 的 SourceFactSet、DryRun facts 和 verdict 机器可消费裁决
- apply 后 `re-export / verify / diff` 自动复核
- post-apply 失败自动 rollback 与 recovery verify
- `run-id + audit directory` 审计包
- `--token-env / --token-file` 安全令牌输入
- `--cert-source-output` 认证模式

策略模板不再接受直接 `--token`；旧策略若仍含 `requiredExecutionToken`，会以 `PBA104` 阻断，必须通过 `--token-env` 或 `--token-file` 显式迁移。其他 runtime command 的 inline token 仅为兼容保留，可能进入 shell history、进程参数或 CI 日志，不应作为生产推荐路径。

但当前仍然只应在下面这类条件下使用：

- 项目已经进入 allowlist
- 风险等级不超过策略阈值
- 当前环境满足支持矩阵
- 执行方持有有效令牌
- 团队接受“受控自动写回试点”而非“全量生产承诺”

如果你需要查看这条能力的工程方案与规格来源，请参考：

- `父仓库 openspec/changes/pb-codex-safe-auto-writeback/proposal.md`（父仓 openspec/changes/pb-codex-safe-auto-writeback/proposal.md）
- `父仓库 openspec/changes/pb-codex-safe-auto-writeback/design.md`（父仓 openspec/changes/pb-codex-safe-auto-writeback/design.md）
- `../../openspec/changes/pb-codex-safe-auto-writeback/tasks.md`（父仓 openspec/changes/pb-codex-safe-auto-writeback/tasks.md）
- [44-自动写回支持矩阵与准入说明](../reference/自动写回支持矩阵与准入说明.md)

## 9. 推荐外部表述

### 推荐写法

> 本系统当前已经完成了 PowerBuilder 9.x 辅助开发工具所需的核心只读分析闭环，可作为 Codex / GitHub Copilot 等 AI 工具的前置协作层，为 PB9 工作区提供导出、校验、差异、报告与宿主浏览能力；双向桥接与写回链路已具备可验证原型，但仍在持续稳定化中。

如果你要写成更贴近最终使用者的目标描述，也可以这样写：

> 对于 `G:\Langchao\国润铜业` 这类 PowerBuilder 项目，Codex 无法直接稳定读取 `.pbl` 代码资产；应先借助 `PbBridge.Cli` 导出为 `.sr*` 文本和结构化清单，再让 Codex 在文本工作区上完成理解、编码建议、批量修改与校验辅助。

### 不推荐写法

- “系统已经完整解决 PB9 自动双向桥接问题”
- “当前已经是生产级稳定写回平台”
- “Codex / Copilot 可以直接安全地自动回写所有 PB9 项目”

## 10. 对最终使用者的推荐姿势

如果你是最终使用者，建议这样用：

1. 先导出 PB 工作区到文本产物
2. 用 Copilot 理解和解释当前对象
3. 用 Codex 做批量整理、规则化修改或文档收口
4. 用 `verify` / `diff` / `report` 做证据化复核
5. 人工批准后，再考虑是否进入导入/回写链路

也就是说：

> **AI 负责理解与候选修改，系统负责校验与证据，人负责批准。**

## 11. 你接下来应该看什么

如果你想快速试用，请先看：

- [21-快速开始](../getting-started/快速开始.md)
- [22-外部PowerBuilder项目接入Codex](../getting-started/外部PowerBuilder项目接入Codex.md)
- 31-用户使用手册（主仓 docs/使用手册/31-用户使用手册.md）
- 32-功能边界与适用范围（主仓 docs/使用手册/32-功能边界与适用范围.md）

如果你想看更深的证据来源，请继续参考：

- [`../pb9-ai-bridge/PROGRESS.md`]（主仓 docs/pb9-ai-bridge/PROGRESS.md）
- [`../pb9-ai-bridge/12-CLI演示操作手册.md`]（主仓 docs/pb9-ai-bridge/12-CLI演示操作手册.md）
- [`../pb9-ai-bridge/13-SharpIDE运行态冒烟检查手册.md`]（主仓 docs/pb9-ai-bridge/13-SharpIDE运行态冒烟检查手册.md）
- [`../pb9-ai-bridge/16-MVP验收基线与核查清单.md`]（主仓 docs/pb9-ai-bridge/16-MVP验收基线与核查清单.md）

## 12. 如果你想把这套审查方式给其他项目复用

本仓库当前**不再把“完整性审查 skill”作为实际加载的项目级 skill 资产使用**。

如果你的目标其实是：

- 帮用户正确使用 `PbBridge.Cli`
- 让 Codex / GitHub Copilot 优先围绕 CLI 主路径给出建议
- 把“导出 → 校验 → 报告 → 差异”的稳定流程移植给其他项目

那么更应该优先看：

- [42-PbBridge.Cli协作模板](../workflows/PbBridge.Cli协作模板.md)

如果你的目标是让**其他项目**复用这套思路，请直接阅读并引用下面这份手册模板：

- [43-AI协作完整性审查模板](../workflows/AI协作完整性审查模板.md)

那份文档的定位是：

- 作为手册的一部分保存
- 以“文档版 skill”的形式提供可复制、可裁剪的 `SKILL.md` 正文
- 供其他项目按自己的目录结构、证据源和能力边界做二次改写

也就是说：

> 本仓库负责提供“如何写”的参考，
> 真正的 skill 应由目标项目自己放进自己的 skill 目录中。

## 13. 一句话总结

### 对 Codex / GitHub Copilot 来说

**当前系统已经足以成为 PB9 的 AI 协作前置层。**

### 对生产级自动写回来说

**当前系统还没有齐全到可以过度承诺。**
