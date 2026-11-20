> 本文档由 `PbBridge.Toolkit` 从父仓库手册同步生成。
> 当前 toolkit 固定提供 `CLI win-x86 + IDE win-x64` 的 Windows 运行时组合；正式写回支持矩阵仍以父仓库事实源为准。
# Codex 与 GitHub Copilot 协作指南

面向当前 Windows Toolkit 的日常 V8 开发，从[第一次完成一次业务变更](../getting-started/第一次完成一次业务变更.md)开始；具体命令复制[分段协作模板](PbBridge.Cli协作模板.md)，逐段审阅结果后继续。Copilot 可辅助当前对象理解和局部编辑，Codex 可处理已授权的跨文件任务；两者都基于真实文本与 CLI 证据工作。

## 1. 给 AI 可信输入与明确范围

按[安装升级](../getting-started/安装与升级说明.md)和[项目接入](../getting-started/外部PowerBuilder项目接入Codex.md)准备完整 Toolkit、项目配置及明确 workspace。提供业务目标、已授权的源码/写回范围、PBW/PBT、目标 PBL/对象键与 `.sr*` 映射；不要让 AI 猜测二进制 PBL 内容或隐式选 workspace。

优先使用本次导出文本、manifest、verify/diff/report 和当前 preflight 的完整结果。stdout 是入口摘要，应读取其指向的实际 JSON 与原始诊断，核对源码、依赖、目标快照及 session。历史报告、旧候选通过与任务勾选只能解释背景，不能替代当前输入和可执行性。

## 2. 最小修改、预检、已授权写回

在授权范围内修改最小 `.sr*`，按[预检段](PbBridge.Cli协作模板.md#1-预检与审阅)检查真实对象、阻塞原因和下一动作。用户已授权源码修改及受控写回时，明确的语法/编译错误可自行最小修复、重新预检，并在门禁允许后继续，不逐次重复确认。`manual-action` 标签本身不撤销授权，应结合实际所需动作判断。

修复后采用新预检及可信依赖计划，核对既有成功对象，避免重复写入；没有源码、依赖或环境变化时，不原样循环 Apply。只有当前任务确已授权且结果允许继续，才执行[独立写回段](PbBridge.Cli协作模板.md#2-确认授权后写回)。不得改结果 JSON、绕过门禁或把人工动作描述拼成命令。

## 3. 按实际锁、漂移和恢复结果处理

不主动扫描 PB IDE 进程，也不把“已关闭 IDE”的回复当预检或写回条件。CLI 检查实际文件锁、目标快照、冲突与恢复；`PblLockSet` 只协调遵守协议的参与者。阻塞时记录具体对象、reason code 与所需动作，不自动终止 IDE 或删除锁绕过。

`recovery-required` 时停止依赖写回，按结果绑定的 promotion intent 和[恢复入口](../getting-started/快速开始.md)处理；不能把备份、正常清理或最终哈希相同当作产品故障恢复验证。7.7.0 真实 PBL 故障回滚仍未验证。无法在授权内解决的原因按阻塞处理（父仓 `docs/使用手册/14-已知限制与发布阻塞.md`，不随包分发）诊断并交接。

## 4. 同一 session 交接给人工，再回填实际证据

当前 Windows 环境不支持 Codex 操控 PB IDE。Regenerate、Full Build、Painter、调试与业务运行验收由用户执行；不通过桌面自动化、UIA、SendKeys、鼠标或临时脚本操作 IDE。这不限制已授权且门禁允许的 CLI 写回。

确需 IDE、人工验收或用户决策时，先完成其余独立工作，再按[交接与证据段](PbBridge.Cli协作模板.md#3-先交接再登记实际证据)生成 handoff，列明 workspace/PBW、PBL/对象、同一 session、失败原因、人工步骤及所需日志/场景结果，暂停依赖步骤。没有结果保持 `not-checked`，已有失败继续保留。

收到实际结果后核对身份和范围，按适用情况 ingest/attest，再刷新同一 session 的交接；过期输入重新预检，不为补证重复 Apply。人工通过为 `attested`，不得冒充 `verified`；图片可能为 `pending-review`。按[业务变更交付视图](../reference/业务变更交付视图.md)分别汇报源码修正、预检、实际写回、IDE 与业务结果，范围不绑定或当前适用性 unknown 时如实保留不确定性。

## 适用参考与历史阅读

- 功能边界（父仓 `docs/使用手册/32-功能边界与适用范围.md`，不随包分发）和[支持矩阵](../reference/自动写回支持矩阵与准入说明.md)：日常 V8 与更高等级 `autonomous-writeback`/生产托管的边界；后者的资格要求不新增为日常前置。
- [编译诊断定位](../reference/编译诊断到原始源码定位.md)与[反馈模板](../reference/Toolkit问题反馈模板.md)：保留原始失败，提供脱敏且可定位的证据。
- [AI 协作完整性审查模板](AI协作完整性审查模板.md)：供其他项目裁剪的文档参考，不是本仓已启用的 skill，也不授予写回权限。
- 旧能力评估与项目评论原文（父仓 `docs/使用手册/archive/2026-11-11-41-Codex与Copilot协作指南.md`，不随包分发）：保留整理前的历史判断和编号，仅修移位后的相对链接；当前操作以本页及 42 为准。旧发行交接与资格入口见[历史索引](../history/历史版本索引.md)。
