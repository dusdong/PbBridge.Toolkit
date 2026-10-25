---
name: pbbridge-powerbuilder-dev-loop
description: 在真实 PowerBuilder 项目中完成 .sr* 修改、V8 预检/Continue Apply、反向确认与人工 IDE 验收交接，收到结果后继续记录证据。
---

# PowerBuilder 开发闭环

## 读取顺序

1. 外部项目 `AGENTS.md`
2. `.pbbridge/PbBridge.Toolkit/CODEX-START.md`
3. `pbbridge-cli` skill
4. 涉及 PowerScript 时读取 `powerbuilder-powerscript` skill

## 标准流程

当前 Windows 环境不支持 Codex 操控 PowerBuilder IDE。遵守 `CODEX-START.md` 的执行边界；不使用桌面自动化、UIA、SendKeys、鼠标坐标或临时脚本操作 PB IDE，也不寻找 GUI 替代工具。已授权的 CLI 写回仍按既有门禁执行。不主动扫描或检查 PB90/PB IDE 是否运行，不把进程存在或“已关闭”回复设为预检、写回的前置条件，也不为此询问许可。由 CLI 的实际文件锁、目标快照、冲突与恢复结果判断能否继续；确有阻断时报告具体对象、原因和所需操作，不自动关闭或终止 IDE 进程。

1. 通过 manifest 或 `pbbridge object find` 确认 `<target-pbl>:<object-type>:<object-name>` 与 workspace。
2. 修改最小范围 `.sr*`，先做语法、DataWindow 结构和 source format 检查。
3. 执行 V8 预检，确认 workspace 身份、`writebackReadiness`、target snapshot、零冲突、计划差异和 blockers。
4. 用户明确写回时使用 `delivery continue --from <preflight>`；项目策略授权时使用 `--apply-if-eligible`。
5. Apply 后读取 `verificationCoverage`、对象级 residual/review、恢复状态和不可变 session evidence。
6. 用户已授权当前任务的源码修改和受控写回时，明确的源码语法/编译错误可自行做最小修复、重新预检，并在门禁通过后继续，无需逐次确认。即使 CLI 将此类错误标为 `manual-action`，也先结合诊断、reason code 和实际所需动作判断；该标签本身不撤销既有授权。
   修复后使用新预检结果及其可信依赖计划继续；核对已有成功对象与当前目标事实，避免重复写入。每次重试必须有源码、依赖或环境事实变化；同一原因在没有新修复依据时仍失败，应报告阻断，禁止原样循环 Apply。源码修正、预检通过、实际写入和 IDE 验收分别汇报，累计写入只计实际成功结果。
   只有实际需要 PB IDE 操作、人工验收、用户决策或无法在授权范围内解决的阻断，才完成其余独立工作后生成 checklist/handoff，列明 workspace/PBW、PBL/对象、session、原因、人工步骤与所需证据，并暂停依赖步骤。`manual-action` 或 `ide-fallback-required` 的人工动作说明不得拼成命令执行，也不得通过修改结果 JSON、跳过门禁或伪造证据继续。
   Regenerate、Full Build、Painter、调试与运行验收由用户完成。未验收项保持 `not-checked`，已有失败或阻断继续保留；允许汇报“自动化部分完成，等待人工验收”。
   收到用户结果后，核对身份并从现有有效 V8 session 加入包装、部署、IDE 日志与人工验收，再刷新 handoff；过期时重新预检，不无依据地重复 Apply。人工确认只能记为 `attested`，不能冒充 `verified`。
7. 只提交业务源码、必要 PBL 与批准的审计证据；local-only 文件不提交。

```powershell
pbbridge delivery close-loop --repo-root . --workspace <id> --object <object-key>=<source-path> --result <v8-preflight.json>
pbbridge delivery continue --from <v8-preflight.json> --apply --result <v8-apply.json>
```

非当前 Delivery/session 必须拒绝；升级后必须重新执行当前 V8 预检。
