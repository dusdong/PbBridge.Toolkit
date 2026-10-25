> 本文档由 `PbBridge.Toolkit` 从父仓库手册同步生成。
> 当前 toolkit 固定提供 `CLI win-x86 + IDE win-x64` 的 Windows 运行时组合；正式写回支持矩阵仍以父仓库事实源为准。
# 外部 PowerBuilder 项目接入 Codex

1. 将 Toolkit 挂载到 `.pbbridge/PbBridge.Toolkit`，项目根 `AGENTS.md` 引用 `CODEX-START.md`。
2. 建立 `pbbridge-project.json` 与每个 workspace 配置，声明 PBW/PBT、source layout、include/exclude、verify policy 和 retention。
3. 用 `pbbridge toolkit entrypoints explain --intent <intent>` 选择入口，并用 object find/export/repair/diff 处理对象。
4. 修改最小范围 `.sr*`，运行 V8 preflight，并把 full result 保存到 workspace 的 `results/delivery-v8/`。
5. 获得授权后使用 `delivery continue --from <v8-preflight.json> --apply|--apply-if-eligible`，检查 post-apply review、promotion intent 与 recovery。
6. 使用 `handoff-summary` 生成人工交接，列明 workspace/PBW、PBL/对象、session、操作步骤和所需日志或场景结果。由用户在 PowerBuilder IDE 完成 Regenerate、Full Build、运行与业务验收；收到实际结果后再向现有有效 session 执行 `ingest-ide-log` 或 `attest`，最后刷新 handoff。

当前 Windows 环境不支持 Codex 操控 PowerBuilder IDE。Codex 不使用桌面自动化、UIA、SendKeys、鼠标坐标或临时脚本操作 PB IDE，不寻找 GUI 替代工具或自动终止 IDE 进程。已授权的 CLI 写回仍按既有门禁执行。不主动扫描或检查 PB90/PB IDE 是否运行，不把进程存在或“已关闭”回复设为预检、写回的前置条件，也不为此询问许可。由 CLI 的实际文件锁、目标快照、冲突与恢复结果判断能否继续；确有阻断时报告具体对象、原因和所需操作，不自动关闭或终止 IDE 进程。

用户已授权当前任务的源码修改和受控写回时，明确的源码语法/编译错误可自行做最小修复、重新预检，并在门禁通过后继续，无需逐次确认。即使 CLI 将此类错误标为 `manual-action`，也先结合诊断、reason code 和实际所需动作判断；该标签本身不撤销既有授权。修复后使用新预检结果及其可信依赖计划继续；核对已有成功对象与当前目标事实，避免重复写入。每次重试必须有源码、依赖或环境事实变化；同一原因在没有新修复依据时仍失败，应报告阻断，禁止原样循环 Apply。源码修正、预检通过、实际写入和 IDE 验收分别汇报，累计写入只计实际成功结果。

只有实际需要 PB IDE 操作、人工验收、用户决策或无法在授权范围内解决的阻断，才完成其余独立工作后生成 checklist/handoff，列明 workspace/PBW、PBL/对象、session、原因、人工步骤与所需证据，并暂停依赖步骤。`manual-action` 或 `ide-fallback-required` 的人工动作说明不得拼成命令执行，也不得通过修改结果 JSON、跳过门禁或伪造证据继续。未验收项保持 `not-checked`，已有失败或阻断继续保留；人工确认记为 `attested`，不能冒充 `verified`。

外部项目不得把 wrapper 变成业务规则引擎，不得隐式发现 workspace，也不得转换、补写或映射非当前 delivery/session JSON 来绕过 V8 门禁。遇到旧输入必须升级后重新生成当前 V8 preflight/session。
