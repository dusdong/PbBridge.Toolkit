---
name: pbbridge-cli
description: 使用 PbBridge.Toolkit 7.6.0 CLI 处理 PowerBuilder 源码、V8 delivery、产物与验收证据。
---

# PbBridge CLI

## 何时使用

- 定位、导出、校验或比较 `.sr*` 对象
- 执行 V8 preflight 与受控 Continue
- 检查 EXE/PBD 包装目标、运行依赖和产物新鲜度
- 导入 PB9 IDE/运行日志、记录人工验收并生成 session handoff
- 解释 Git/PBL 脏状态、检查本机目录 hygiene、查询 V8 session

对象定位与修复优先使用 `pbbridge object find`、`pbbridge object export`、`pbbridge object repair`、`pbbridge object diff --semantic`。不确定入口时运行 `pbbridge toolkit entrypoints explain --intent <intent>`。

## 主路径

下列证据命令仅在用户完成对应验收并提供实际结果后执行；没有结果时先用 `handoff-summary` 交接，不能照抄 `attest --status passed` 示例当作验收事实。

```powershell
pbbridge delivery close-loop --repo-root . --workspace canyin --object "app.pbl:window:w_example=src/app.pbl.src/w_example.srw" --result .pbbridge/workspaces/canyin/results/delivery-v8/preflight.json
pbbridge delivery continue --from .pbbridge/workspaces/canyin/results/delivery-v8/preflight.json --apply --result .pbbridge/workspaces/canyin/results/delivery-v8/apply.json
pbbridge target packaging inspect --target cy.pbt --artifact-root bin --session <id> --result packaging.json
pbbridge target deployment verify --packaging-result packaging.json --dependency-manifest .pbbridge/runtime-dependencies.json --artifact-root bin --session <id> --result deployment.json
pbbridge delivery ingest-ide-log --session <id> --log build.log
pbbridge delivery attest --session <id> --stage business --status passed --actor <id> --note "业务场景通过"
pbbridge delivery handoff-summary --session <id> --format markdown
pbbridge git governance --project-root . --workspace canyin
pbbridge pbl drift-remediation --project-root . --workspace canyin
pbbridge hygiene fix --project-root . --what-if
pbbridge delivery explain --repo-root . --workspace canyin --session <id> --why-blocked
```

## 契约规则

1. current full/compact 必须是 `pbbridge-v8-delivery` / `pbbridge-v8-compact-summary`，schemaVersion 8。
2. 非当前 Delivery/session 必须拒绝；升级后重新执行当前 V8 preflight，不调用兼容 reader。
3. `conflictPrecheck=not-checked` 时写回必须 blocked。
4. `verificationCoverage` 固定包含源码、快照、冲突、写回、复核、编译、包装、部署、运行和业务十项。
5. `attested` 与 `verified` 不得混用；发布状态据此区分 `ready-with-attestations` 和 `ready`。
6. Full Build 是 `manual-action`；PbBridge 不接管 PB9 GUI。当前 Windows 环境不支持 Codex 操控 PowerBuilder IDE；Codex 不使用桌面自动化、UIA、SendKeys、鼠标坐标或临时脚本操作 PB IDE，也不寻找 GUI 替代工具或自动终止 IDE 进程。
   不主动扫描或检查 PB90/PB IDE 是否运行，不把进程存在或“已关闭”回复设为预检、写回的前置条件，也不为此询问许可。由 CLI 的实际文件锁、目标快照、冲突与恢复结果判断能否继续；确有阻断时报告具体对象、原因和所需操作，不自动关闭或终止 IDE 进程。
7. 多对象 Apply 使用可信拓扑；advisory 动态线索不自动排序，任一失败或不确定状态都会停止后续 importer。
8. `git governance` 每个路径只给一个 commit/ignore/review/block/defer 决策；PBL 决策必须能追溯到正交 facts。
9. 用户已授权当前任务的源码修改和受控写回时，明确的源码语法/编译错误可自行做最小修复、重新预检，并在门禁通过后继续，无需逐次确认。即使 CLI 将此类错误标为 `manual-action`，也先结合诊断、reason code 和实际所需动作判断；该标签本身不撤销既有授权。
   修复后使用新预检结果及其可信依赖计划继续；核对已有成功对象与当前目标事实，避免重复写入。每次重试必须有源码、依赖或环境事实变化；同一原因在没有新修复依据时仍失败，应报告阻断，禁止原样循环 Apply。源码修正、预检通过、实际写入和 IDE 验收分别汇报，累计写入只计实际成功结果。
   只有实际需要 PB IDE 操作、人工验收、用户决策或无法在授权范围内解决的阻断，才完成其余独立工作后生成 checklist/handoff，列明 workspace/PBW、PBL/对象、session、原因、人工步骤与所需证据，并暂停依赖步骤。`manual-action` 或 `ide-fallback-required` 的人工动作说明不得拼成命令执行，也不得通过修改结果 JSON、跳过门禁或伪造证据继续。
10. 未验收项保持 `not-checked`，已有失败或阻断继续保留。用户提供结果后从现有有效 session 继续，过期时重新预检，不为补证据无依据地重复 Apply。已授权的 CLI 写回仍按既有门禁执行。

```powershell
pbbridge schema show pbbridge-v8-delivery
pbbridge schema explain pbbridge-v8-delivery
pbbridge contract validate .pbbridge/workspaces/canyin/results/delivery-v8/preflight.json
```

Toolkit 更新默认 github/main；显式同官方仓库别名可用。TargetCommit 固定 fetched main 或祖先，拒绝回退；先验证原始 ZIP 恢复，再预取并核验 LFS 缓存，checkout 精确 SHA 后验证 checksums。缓存成功不证明独立下载，WhatIf 不切换。
