# 外部项目模板

模板版本为 `7.6.0`。`pbbridge-delivery-close-loop.ps1` 是 V8 纯预检入口，`pbbridge-delivery-continue.ps1` 是受 `ShouldProcess` 保护的写回入口。

当前业务运行时为 PowerShell 7.4+。先运行 `./scripts/pbbridge-runtime-check.ps1` 获取结构化准入结果，随后统一使用 `pwsh` 执行 wrapper；Windows PowerShell 5.1 不再是业务运行时。

对象定位与修复入口为 `pbbridge object find`、`pbbridge object export`、`pbbridge object repair`、`pbbridge object diff --semantic`；不确定入口时运行 `pbbridge toolkit entrypoints explain --intent object-find|object-export|object-repair|object-diff`。

```powershell
./scripts/pbbridge-toolkit-upgrade-check.ps1 -RepoRoot . -Workspace canyin
./scripts/pbbridge-performance-benchmark.ps1 -RepoRoot . -WorkspaceName canyin -Profile medium -CacheMode both -RunnerClassId pbbridge-toolkit-win-x86 -RedactPaths
./scripts/pbbridge-readonly-sync.ps1 -RepoRoot . -WorkspaceName canyin -WorkspacePath 'CanYin.pbw'
./scripts/pbbridge-delivery-close-loop.ps1 -RepoRoot . -Workspace canyin -Object 'app.pbl:window:w_example=src/app.pbl.src/w_example.srw' -ResultJsonPath '.pbbridge/workspaces/canyin/results/delivery-v8/preflight.json'
./scripts/pbbridge-delivery-continue.ps1 -RepoRoot . -From '.pbbridge/workspaces/canyin/results/delivery-v8/preflight.json' -Apply -Confirm:$false
pbbridge git governance --project-root . --workspace canyin
pbbridge hygiene check --project-root .
pbbridge delivery summary --repo-root . --workspace canyin --session <id>
```

仅 Git hygiene 警告默认返回 0；需要严格门禁时使用 `-StrictGitHygiene`。官方 V5/V7.2 项目必须通过当前 Plan → Decide → Apply 迁移，禁止手工替换 bootstrap 或修改版本。

交付反馈读取 `operationAssessments` 和 typed `nextAction`。全局 readonly-sync 阻断保持原状态；缺少当前对象/依赖事实时，object-writeback 为未评估，不由发布验收决定 Apply。确定性源码错误先修正并重新 preflight；只对实际文件占用处理环境；partial 保留成功对象，先核对其当前源码/目标，再处理剩余对象。

摘要是静态文件。保存后可显式只读对照：
```text
pbbridge delivery summary --repo-root . --workspace canyin --session <id> --compare-summary saved-summary.json --result current-summary.json
```
输出 current/stale/unknown/unavailable，原文件不刷新；输入、session、证据、源码或 PBL 不能作为输出路径。current 只证明观察时点 session 内容一致。旧产品/旧构建文件仅供离线审计，不支持当前 CLI 读取或执行。

全局诊断可使用 `--delivery-result <current-full.json>`、`--governance-input <git-governance.json>` 和重复 `--commit-file <path>` 说明明确范围；源码可提交不推出 PBL 可提交或发布就绪。正式执行仍重新检查既有门禁。

本次 Apply 的 `performance.executionTiming` 使用单调时间，覆盖执行、恢复和 session/evidence 收尾；排除参数解析、进程启动、最终计时文件/结果输出和人工等待。子阶段有 batch/parent，不能重复求和。旧记录缺少计时为 unavailable，崩溃缺终态为 partial，未启动阶段没有成功耗时。

运行依赖按 `.pbbridge/runtime-dependencies.json` 声明，初始模板为 `runtime-dependencies.example.json`。非当前 Delivery/session 输入必须拒绝；升级后重新执行当前 V8 preflight。

多对象写回通过重复 `--depends-on <dependent>=<dependency>` 声明可信边；工具也会提取请求内可唯一定位的继承和直接静态调用。动态调用只作为 advisory，不改变写回顺序。任一对象导入或反向复核失败后，后续 importer 不再调用。

`hygiene fix` 在 7.6.0 只支持 `--what-if`，`delivery cleanup` 也只提供可再生候选预览；二者都不写 `.gitignore`、不删除证据。
## 发行身份与升级恢复

运行包内 `PbBridge.Cli.exe version --identity --repo-root .` 查看实际五元身份及 `产品版本 / build <CLI hash 前12位> / toolkit <实际 commit>`。身份缺失时查看 `identityReasonCodes`，不要以短标识授权 Apply。实际 Toolkit HEAD 和父仓 gitlink 差异会同时展示。

`pbbridge-toolkit-update.ps1` 预览旧新完整身份、祖先关系及恢复状态。提供旧树外冻结记录 `-ReleaseRecordPath`、原包本地渠道 `-RecoveryArtifactRoot` 和全新隔离目录 `-RecoveryExtractionRoot` 才能核验实际恢复；缺少原包、哈希漂移或只有源码时禁止自动切换。`pbbridge-toolkit-upgrade-check.ps1` 可用同名参数及独立 `-SnapshotPreviewPath` 保存该预览。恢复仅针对工具包，不恢复 PBL、源码或 session；升级后按 workspace 重新生成当前 facts，保留定制与冲突。
新产品发行的恢复材料须同时保存冻结 record、publication-receipt.json 和同目录 manifest-finalization.json；生产者、资格消费者与恢复入口共同核验这些原始字节，不改写 pre-tag record 的状态。执行缓存还需与声明 runtime 的完整文件清单及实际加载程序集一致，相同 EXE 不代表相同构建。
