## PbBridge V8 delivery

- 唯一当前 full schema：`pbbridge-v8-delivery` / 8。
- 唯一当前 compact schema：`pbbridge-v8-compact-summary` / 8。
- 必须用 `--repo-root` 与可选 `--workspace <id>` 解析显式 workspace；禁止传路径冒充 workspace id。
- 日常流程：V8 preflight → Continue Apply/ApplyIfEligible → post-apply review → 生成人工验收交接 → 用户在 PB IDE 验收 → 收到结果后导入包装/部署/IDE/运行/业务 evidence。
- 非当前 Delivery/session 输入必须拒绝；升级后重新执行当前 V8 预检。
- 当前 Windows 环境不支持 Codex 操控 PowerBuilder IDE；不使用桌面自动化、UIA、SendKeys、鼠标坐标或临时脚本操作 PB IDE，不寻找 GUI 替代工具。已授权的 Toolkit CLI 写回仍按既有门禁执行。
- Regenerate、Full Build、Painter、调试与运行验收由用户完成。
- 不主动扫描或检查 PB90/PB IDE 是否运行，不把进程存在或“已关闭”回复设为预检、写回的前置条件，也不为此询问许可。由 CLI 的实际文件锁、目标快照、冲突与恢复结果判断能否继续；确有阻断时报告具体对象、原因和所需操作，不自动关闭或终止 IDE 进程。
- 用户已授权当前任务的源码修改和受控写回时，明确的源码语法/编译错误可自行做最小修复、重新预检，并在门禁通过后继续，无需逐次确认。即使 CLI 将此类错误标为 `manual-action`，也先结合诊断、reason code 和实际所需动作判断；该标签本身不撤销既有授权。
- 修复后使用新预检结果及其可信依赖计划继续；核对已有成功对象与当前目标事实，避免重复写入。每次重试必须有源码、依赖或环境事实变化；同一原因在没有新修复依据时仍失败，应报告阻断，禁止原样循环 Apply。源码修正、预检通过、实际写入和 IDE 验收分别汇报，累计写入只计实际成功结果。
- 只有实际需要 PB IDE 操作、人工验收、用户决策或无法在授权范围内解决的阻断，才完成其余独立工作后生成 checklist/handoff，列明 workspace/PBW、PBL/对象、session、原因、人工步骤与所需证据，并暂停依赖步骤。`manual-action` 或 `ide-fallback-required` 的人工动作说明不得拼成命令执行，也不得通过修改结果 JSON、跳过门禁或伪造证据继续。
- 未验收项保持 `not-checked`，已有失败或阻断继续保留；人工确认只能记为 `attested`，不能冒充 `verified`。允许汇报“自动化部分完成，等待人工验收”。
- 用户提供结果后从现有有效 session 继续，过期时重新预检，不为补验收证据无依据地重复 Apply。
- 五操作说明读取 `operationAssessments`：sync、object-writeback、source-commit、pbl-commit、release 分别使用其范围事实；`evaluated=false` 不代表许可。全局同步阻断仍保留，缺少对象事实时先生成目标对象 preflight。
- 静态摘要不会自动刷新。显式执行 `pbbridge delivery summary --session <id> --compare-summary <saved-summary.json> --result <new-summary.json>`，对照 current/stale/unknown/unavailable；必须使用独立输出路径。current 只表示观察时点 session 内容一致，不代替当前源码/PBL 守卫和人工验收。
- 旧产品或旧构建的 summary/session 不进入当前 CLI；保留原字节供离线审计。计时只读取 `performance.executionTiming`，partial/unavailable 不按零统计；不把人工等待或父子阶段重复计入总计。
