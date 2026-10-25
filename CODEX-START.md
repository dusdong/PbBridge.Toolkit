# CODEX-START.md

这是 PbBridge.Toolkit `7.5.3` 的 Codex 启动入口。当前 `.sr*` 交付只使用 V8 delivery；非当前 Delivery/session 输入必须在写入前拒绝，不能继续 Apply、生成当前 handoff 或加入 V8 session。

## Codex 与 PowerBuilder IDE 的执行边界

- 当前 Windows 协作环境不支持 Codex 操控 PowerBuilder IDE。Codex 使用 PbBridge CLI、项目脚本及文件操作完成已授权工作。
- Codex 不尝试通过桌面自动化、UIA、SendKeys、鼠标坐标或临时脚本操作 PB IDE，也不为此安装或寻找替代工具。此边界不限制 Toolkit 已支持且获得授权的 CLI 写回。
- Regenerate、Full Build、Painter 操作、交互调试与业务运行验收由用户完成。
- 不主动扫描或检查 PB90/PB IDE 是否运行，不把进程存在或“已关闭”回复设为预检、写回的前置条件，也不为此询问许可。由 CLI 的实际文件锁、目标快照、冲突与恢复结果判断能否继续；确有阻断时报告具体对象、原因和所需操作，不自动关闭或终止 IDE 进程。
- 用户已授权当前任务的源码修改和受控写回时，明确的源码语法/编译错误可自行做最小修复、重新预检，并在门禁通过后继续，无需逐次确认。即使 CLI 将此类错误标为 `manual-action`，也先结合诊断、reason code 和实际所需动作判断；该标签本身不撤销既有授权。
- 修复后使用新预检结果及其可信依赖计划继续；核对已有成功对象与当前目标事实，避免重复写入。每次重试必须有源码、依赖或环境事实变化；同一原因在没有新修复依据时仍失败，应报告阻断，禁止原样循环 Apply。源码修正、预检通过、实际写入和 IDE 验收分别汇报，累计写入只计实际成功结果。
- 只有实际需要 PB IDE 操作、人工验收、用户决策或无法在授权范围内解决的阻断，才完成其余独立工作后生成 checklist/handoff，列明 workspace/PBW、PBL/对象、session、原因、人工步骤与所需证据，并暂停依赖步骤。`manual-action` 或 `ide-fallback-required` 的人工动作说明不得拼成命令执行，也不得通过修改结果 JSON、跳过门禁或伪造证据继续。
- 交接应列出 workspace/PBW、目标 PBL/对象、session、已完成步骤、具体人工操作及需要返回的日志或场景结果。允许汇报“自动化部分完成，等待人工验收”。
- 未取得验收证据时，相应项目保持 `not-checked`；已有失败或阻断结论继续保留。人工确认按既有契约记为 `attested`，不能冒充 `verified`。
- 收到用户结果后，核对 workspace、对象与 session 身份，从现有有效 session 继续导入证据；事实过期时按既有门禁重新预检，不为补验收证据无依据地重复 Apply。

## 启动检查

1. 读取外部项目根目录 `AGENTS.md` 和本文件。
2. 核对 Toolkit VERSION、manifest、runtime contract 与 template manifest 均为 `7.5.3`。
3. 运行 `.pbbridge/PbBridge.Toolkit/runtime/cli/win-x86/PbBridge.Cli.exe doctor`。
4. 显式选择 workspace，运行 `pbbridge toolkit preflight --project-root . --workspace <id>`。

## V8 交付主路径

```powershell
pbbridge delivery close-loop --repo-root . --workspace canyin --object "app.pbl:window:w_example=src/app.pbl.src/w_example.srw" --result .pbbridge/workspaces/canyin/results/delivery-v8/preflight.json
pbbridge delivery continue --from .pbbridge/workspaces/canyin/results/delivery-v8/preflight.json --apply --result .pbbridge/workspaces/canyin/results/delivery-v8/apply.json
pbbridge git governance --project-root . --workspace canyin
pbbridge delivery summary --repo-root . --workspace canyin --session <id>
```

wrapper 对应为：

```powershell
./scripts/pbbridge-delivery-close-loop.ps1 -RepoRoot . -Workspace canyin -Object 'app.pbl:window:w_example=src/app.pbl.src/w_example.srw' -ResultJsonPath '.pbbridge/workspaces/canyin/results/delivery-v8/preflight.json'
./scripts/pbbridge-delivery-continue.ps1 -RepoRoot . -From '.pbbridge/workspaces/canyin/results/delivery-v8/preflight.json' -Apply -Confirm:$false
```

`close-loop` 只预检；`continue` 才进入受 `ShouldProcess`、事实新鲜度、目标快照、冲突和 policy 约束的写回。

## 结果消费

1. stdout 是 `pbbridge-v8-compact-summary`，完整事实是 `pbbridge-v8-delivery`。
2. 分开读取 `writebackReadiness`、`ideReadiness`、`releaseReadiness` 与固定十项 `verificationCoverage`。
3. 结合 `nextAction` 类型、reason code、诊断和既有授权判断下一步；按上述边界修复明确源码错误。`manual-action` 的说明不是可执行命令。
4. 人工声明只能产生 `attested`，不能伪装为 `verified`。
5. Apply 后先生成 session 人工验收交接；用户完成验收并提供结果后，再导入 IDE 日志、检查包装/部署产物并记录 runtime/business 验收。
6. 多对象请求用重复 `--depends-on <dependent>=<dependency>` 声明可信依赖；preflight 固化 `plannedOrder` 与 `trustedPlanHash`。
7. 提交前先读 `git governance` 的唯一决策；本机目录缺失规则只用 `hygiene fix --what-if` 预览。

阻断解释与本机清理预览：

```powershell
pbbridge delivery explain --repo-root . --workspace canyin --session <id> --why-blocked
pbbridge delivery cleanup --repo-root . --workspace canyin --session <id> --what-if
```

PbBridge 不执行 PB9 GUI 编译、调试或业务测试。
