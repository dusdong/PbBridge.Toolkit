# PbBridge.Toolkit

当前版本：`7.6.1`。

## 当前入口

1. Codex：`CODEX-START.md`
2. CLI：`runtime/cli/win-x86/PbBridge.Cli.exe`
3. V8 preflight/continue wrapper：`templates/external-project/pbbridge-delivery-close-loop.ps1`、`pbbridge-delivery-continue.ps1`
4. 共享 PowerShell module：`templates/external-project/PbBridge.Wrapper.psm1`
5. 项目/工作区配置示例：`templates/external-project/pbbridge-project.example.json`、`pbbridge-workspace.example.json`
6. 文档：`docs/README.md`

V8 `delivery close-loop` 纯预检与 `delivery continue --from <preflight>` 是当前 `.sr*` 写回主路径。非当前 Delivery/session 输入会在当前执行前被拒绝。

`pbbridge delivery history --session-file <path> [--result <new-independent-json>]` 仅读取已知 7.5.2/7.5.3/7.6.0 V8 session。默认 stdout，显式结果须为既存独立任务目录的新 JSON。独立报告为 `pbbridge-delivery-history` schemaVersion 1、reportMode historical-read-only、canContinue false；原状态仅在 recordedState，当前未评估，附件 not-rechecked。查询不刷新、不恢复、不写原件；原 session 与报告均不能作为当前执行或 evidence 输入。

当前 Windows 环境不支持 Codex 操控 PowerBuilder IDE。Apply 后由 Codex 生成人工交接，用户执行 Regenerate、Full Build 与业务运行验收；收到实际结果后再记录证据。未验收项保持 `not-checked`，人工确认与机器验证分别报告。具体执行边界见 `CODEX-START.md`。
