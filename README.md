# PbBridge.Toolkit

当前版本：`7.5.3`。

## 当前入口

1. Codex：`CODEX-START.md`
2. CLI：`runtime/cli/win-x86/PbBridge.Cli.exe`
3. V8 preflight/continue wrapper：`templates/external-project/pbbridge-delivery-close-loop.ps1`、`pbbridge-delivery-continue.ps1`
4. 共享 PowerShell module：`templates/external-project/PbBridge.Wrapper.psm1`
5. 项目/工作区配置示例：`templates/external-project/pbbridge-project.example.json`、`pbbridge-workspace.example.json`
6. 文档：`docs/README.md`

V8 `delivery close-loop` 纯预检与 `delivery continue --from <preflight>` 是当前 `.sr*` 写回主路径。非当前 Delivery/session 输入会在写入前被拒绝；历史行为只通过正式 Git commit/tag 追溯。

当前 Windows 环境不支持 Codex 操控 PowerBuilder IDE。Apply 后由 Codex 生成人工交接，用户执行 Regenerate、Full Build 与业务运行验收；收到实际结果后再记录证据。未验收项保持 `not-checked`，人工确认与机器验证分别报告。具体执行边界见 `CODEX-START.md`。
