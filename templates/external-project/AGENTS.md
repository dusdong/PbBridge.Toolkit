<!-- PbBridge-TemplateVersion: 7.6.0 -->
# 项目协作规则

1. 先读取本文件中的项目私有约束，再读取 `.pbbridge/PbBridge.Toolkit/CODEX-START.md`。
2. PowerBuilder 业务源码以受管 `.sr*` 为事实源；PBL 写回后由 Codex 反向确认并交接用户完成 IDE/运行验收，收到结果后再记录证据。
3. 当前唯一交付主路径是 V8 `delivery close-loop` 预检加 `delivery continue` 写回。
4. 对象键固定为 `<workspace-relative-pbl-path>:<object-type>:<object-name>`。
5. 非当前 Delivery/session JSON 必须拒绝，不得触发写操作或加入当前 session。
6. 多对象 V8 Apply 必须使用当前 preflight 的 trusted dependency plan；依赖漂移后重新预检。
7. 提交前运行 `pbbridge git governance --workspace <id>`；不得把本机会话、缓存、诊断或无证据二进制漂移加入提交。

对象定位与修复使用 `pbbridge object find`、`pbbridge object export`、`pbbridge object repair`、`pbbridge object diff --semantic`；不确定入口时运行 `pbbridge toolkit entrypoints explain --intent object-find|object-export|object-repair|object-diff`。

```powershell
./scripts/pbbridge-readonly-sync.ps1 -RepoRoot . -WorkspaceName canyin -WorkspacePath 'CanYin.pbw'
./scripts/pbbridge-delivery-close-loop.ps1 -RepoRoot . -Workspace canyin -Object 'app.pbl:window:w_example=src/app.pbl.src/w_example.srw' -ResultJsonPath '.pbbridge/workspaces/canyin/results/delivery-v8/preflight.json'
./scripts/pbbridge-delivery-continue.ps1 -RepoRoot . -From '.pbbridge/workspaces/canyin/results/delivery-v8/preflight.json' -Apply -Confirm:$false
```

- `close-loop` 纯预检，不接受 Apply 参数。
- `continue` 通过 `ShouldProcess`、事实新鲜度、目标漂移和冲突门禁后才写回。
- 分开读取写回、IDE 和发布 readiness；按带类型的 `nextAction` 行动。
- 当前 Windows 环境不支持 Codex 操控 PowerBuilder IDE；不使用桌面自动化、UIA、SendKeys、鼠标坐标或临时脚本操作 PB IDE，不寻找 GUI 替代工具。已授权的 Toolkit CLI 写回仍按既有门禁执行。
- Regenerate、Full Build、Painter、调试与运行验收由用户完成。
- 不主动扫描或检查 PB90/PB IDE 是否运行，不把进程存在或“已关闭”回复设为预检、写回的前置条件，也不为此询问许可。由 CLI 的实际文件锁、目标快照、冲突与恢复结果判断能否继续；确有阻断时报告具体对象、原因和所需操作，不自动关闭或终止 IDE 进程。
- 用户已授权当前任务的源码修改和受控写回时，明确的源码语法/编译错误可自行做最小修复、重新预检，并在门禁通过后继续，无需逐次确认。即使 CLI 将此类错误标为 `manual-action`，也先结合诊断、reason code 和实际所需动作判断；该标签本身不撤销既有授权。
- 修复后使用新预检结果及其可信依赖计划继续；核对已有成功对象与当前目标事实，避免重复写入。每次重试必须有源码、依赖或环境事实变化；同一原因在没有新修复依据时仍失败，应报告阻断，禁止原样循环 Apply。源码修正、预检通过、实际写入和 IDE 验收分别汇报，累计写入只计实际成功结果。
- 只有实际需要 PB IDE 操作、人工验收、用户决策或无法在授权范围内解决的阻断，才完成其余独立工作后生成 checklist/handoff，列明 workspace/PBW、PBL/对象、session、原因、人工步骤与所需证据，并暂停依赖步骤。`manual-action` 或 `ide-fallback-required` 的人工动作说明不得拼成命令执行，也不得通过修改结果 JSON、跳过门禁或伪造证据继续。
- 未验收项保持 `not-checked`，已有失败或阻断继续保留；人工确认只能记为 `attested`，不能冒充 `verified`。允许汇报“自动化部分完成，等待人工验收”。
- 用户提供结果后从现有有效 session 继续，过期时重新预检，不为补验收证据无依据地重复 Apply。
- `delivery summary` 是稳定交付索引；阻断用 `delivery explain --why-blocked`，清理只允许 `delivery cleanup --what-if`。
- 静态 summary 不会刷新；需要对照时使用 `delivery summary --session <id> --compare-summary <saved.json> --result <new.json>`。原文件、session 与证据保持只读；current 只证明观察时点内容一致。读取 `operationAssessments` 的 evaluated 与 scope，不把同步或发布结论泛化为对象 Apply，也不从源码可提交推断 PBL 可提交。
