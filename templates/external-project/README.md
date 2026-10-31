# 外部项目模板

模板版本为 `7.6.1`。`pbbridge-delivery-close-loop.ps1` 是 V8 纯预检入口，`pbbridge-delivery-continue.ps1` 是受 `ShouldProcess` 保护的写回入口。

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

`hygiene fix` 在 7.6.1 只支持 `--what-if`，`delivery cleanup` 也只提供可再生候选预览；二者都不写 `.gitignore`、不删除证据。
## 发行身份与升级恢复

运行包内 `PbBridge.Cli.exe version --identity --repo-root .` 查看实际五元身份及 `产品版本 / build <CLI hash 前12位> / toolkit <实际 commit>`。身份缺失时查看 `identityReasonCodes`，不要以短标识授权 Apply。实际 Toolkit HEAD 和父仓 gitlink 差异会同时展示。

`pbbridge-toolkit-update.ps1` 预览旧新完整身份、祖先关系及恢复状态。提供旧树外冻结记录 `-ReleaseRecordPath`、原包本地渠道 `-RecoveryArtifactRoot` 和全新隔离目录 `-RecoveryExtractionRoot` 才能核验实际恢复；缺少原包、哈希漂移或只有源码时禁止自动切换。`pbbridge-toolkit-upgrade-check.ps1` 可用同名参数及独立 `-SnapshotPreviewPath` 保存该预览。恢复仅针对工具包，不恢复 PBL、源码或 session；升级后按 workspace 重新生成当前 facts，保留定制与冲突。
新产品发行的恢复材料须同时保存冻结 record、publication-receipt.json 和同目录 manifest-finalization.json；生产者、资格消费者与恢复入口共同核验这些原始字节，不改写 pre-tag record 的状态。执行缓存还需与声明 runtime 的完整文件清单及实际加载程序集一致，相同 EXE 不代表相同构建。

### 旧入口与三种恢复用途（7.6.1 开发态合同）

默认 `CompleteQualification` 仍要求完整发行材料。`HistoricalRecovery` 只适用于受支持的 7.5.3 限定回执及原始 ZIP：必须同时提供 `ReleaseRecordPath`、`PublicationReceiptPath`、`RecoveryArtifactRoot`、新的 `RecoveryExtractionRoot`；原 ZIP 缺失时保持阻断。7.5.3 身份不能替代 7.6.0 安装身份。

`InstalledCandidateRecovery` 只允许清洁的 7.6.0 GitHub 候选向 7.6.1 普通快进。显式提供 `ToolkitRoot` 和树外 `RecoveryExtractionRoot`，不得混入上述 record/receipt/artifact 参数或历史断代确认。整个 Git 文件集合、已还原 LFS、checksums、runtime inventory、五元身份及副本 version/doctor 全通过后才生成 `recovery-record.json`。副本位于恢复根的 `toolkit`；已有完整目录重新核验后只读复用，中断、缺件、篡改或身份不符均拒绝，用户自行保留现场并选择新目录。

旧 7.5.3/7.6.0 wrapper 无须认识新参数。只需旧消费项目、其 Toolkit Git 仓库和已经独立核验的官方目标 commit。先在新的 PowerShell 7.4+ 进程核对 Toolkit remote 及父仓选定 submodule 的 `.gitmodules`/本地 URL 已显式对齐 GitHub，并 fetch 官方 main；`origin` 等同源别名可替换下列 `github`。下面完整示例先从目标 Git blob 取得随 Toolkit 分发的引导脚本自身，核对它的 Git blob OID 后才执行；引导脚本再取得并核对 updater、Wrapper、ReleaseIdentity 三个同提交文件。无需父仓源码、旧 wrapper 参数或全局函数替换。当前尚无官方 7.6.1；合成目标仅用于开发测试。

```powershell
# PB761-CONSUMER-BOOTSTRAP-BEGIN
# 在新 pwsh -NoProfile 进程内填写这五个绝对路径/身份变量。
# $toolkit = 'C:/project/.pbbridge/PbBridge.Toolkit'
# $project = 'C:/project'
# $target = '<独立核验的官方目标40位SHA>'
# $task = 'C:/CodexRuns/my-upgrade-new' # 必须全新，且在项目和安装树外
# $remote = 'github'
$toolkit = [IO.Path]::GetFullPath($toolkit)
$task = [IO.Path]::GetFullPath($task)
if ($target -cnotmatch '^[0-9a-f]{40}$' -or (Test-Path -LiteralPath $task)) { throw 'bootstrap-target-or-output-invalid' }
foreach ($inputRoot in @($toolkit,$project)) {
    $inputRoot = [IO.Path]::GetFullPath($inputRoot).TrimEnd('\','/')
    if ($task.Equals($inputRoot,[StringComparison]::OrdinalIgnoreCase) -or $task.StartsWith($inputRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'bootstrap-output-overlap' }
}
$ancestor = $task
while ($ancestor) {
    if ((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'bootstrap-output-link' }
    $parent = Split-Path -Parent $ancestor
    if ($parent -eq $ancestor) { break }; $ancestor = $parent
}
$url = (@(& git -C $toolkit remote get-url --all $remote) -join "`n").Trim()
if ($LASTEXITCODE -ne 0 -or $url -cnotmatch '\A(?:https://github\.com/dusdong/PbBridge\.Toolkit(?:\.git)?|git@github\.com:dusdong/PbBridge\.Toolkit(?:\.git)?|ssh://git@github\.com/dusdong/PbBridge\.Toolkit(?:\.git)?)\z') { throw 'bootstrap-source-not-official' }
& git -C $toolkit merge-base --is-ancestor $target "refs/remotes/$remote/main"
if ($LASTEXITCODE -ne 0) { throw 'bootstrap-target-not-main-history' }
$blob = "${target}:templates/external-project/prepare-toolkit-upgrade-entry.ps1"
$oid = (@(& git -C $toolkit rev-parse --verify $blob) -join '').Trim()
if ($LASTEXITCODE -ne 0 -or $oid -cnotmatch '^[0-9a-f]{40}$') { throw 'bootstrap-blob-missing' }
$info = [Diagnostics.ProcessStartInfo]::new('git')
$info.UseShellExecute=$false; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
foreach ($arg in @('-C',$toolkit,'cat-file','blob',$blob)) { $info.ArgumentList.Add($arg) }
$process=[Diagnostics.Process]::Start($info); $errors=$process.StandardError.ReadToEndAsync(); $memory=[IO.MemoryStream]::new()
try {
    $process.StandardOutput.BaseStream.CopyTo($memory); $process.WaitForExit(); $null=$errors.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { throw 'bootstrap-blob-read-failed' }
    $bytes=$memory.ToArray()
} finally { $memory.Dispose(); $process.Dispose() }
$hash=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA1)
try {
    $hash.AppendData([Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)"+[char]0)); $hash.AppendData($bytes)
    if ([Convert]::ToHexString($hash.GetHashAndReset()).ToLowerInvariant() -cne $oid) { throw 'bootstrap-blob-mismatch' }
} finally { $hash.Dispose() }
$null=[IO.Directory]::CreateDirectory($task)
$bootstrap=Join-Path $task 'prepare-toolkit-upgrade-entry.ps1'
$stream=[IO.File]::Open($bootstrap,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $stream.Write($bytes); $stream.Flush($true) } finally { $stream.Dispose() }
$entry=Join-Path $task 'entry'
& $bootstrap -ToolkitRepository $toolkit -Remote $remote -TargetCommit $target -EntryRoot $entry
$upgradeArgs=@('-RepoRoot',$project,'-ToolkitRoot',$toolkit,'-Remote',$remote,'-Branch','main','-TargetCommit',$target,'-RecoveryPurpose','InstalledCandidateRecovery','-RecoveryExtractionRoot',(Join-Path $task 'recovery'),'-ResultPath',(Join-Path $task 'check.json'),'-Apply','-WhatIf')
& $bootstrap -ToolkitRepository $toolkit -Remote $remote -TargetCommit $target -EntryRoot $entry -Run -UpdaterArguments $upgradeArgs
# PB761-CONSUMER-BOOTSTRAP-END
```

先审查 check.json；实际 Apply 使用同一绑定引导脚本/目标，另选结果路径并从 `$upgradeArgs` 移除 `-WhatIf`。检查、恢复副本准备和实际切换分别记录。缺件、混版、非官方来源及输出链接均在执行前拒绝。历史原包用途将 upgradeArgs 中候选用途及对应材料改为前述 HistoricalRecovery 合同，不混用两种材料。

ResultPath 默认仅使用项目专用 `.pbbridge/toolkit-update-check.json`；自定义结果须为项目、安装和恢复树外的独立 JSON 路径。已有 updater 查询报告可刷新，其他已存在文件不能覆盖。Git 管理路径、业务项目内的其他路径、安装/恢复副本/记录及链接输出在任何写入（包括异常摘要）前拒绝，错误直接返回，不再把错误写到被拒绝路径。合法独立结果在 WhatIf 下仍实际保存。

`-Apply -WhatIf` 可实际创建/验证显式恢复目录并写 ResultPath，可 fetch 对象和远程跟踪引用；不切换安装 HEAD、index 或文件，不修改父仓 gitlink/配置、业务 PBL、源码和 session。普通检查和实际 Apply 分别记录。候选副本只证明 `installed-candidate-copy / toolkit-only / candidate-recovery-only`，`publishable=false`、`authorizationTransferable=false`；不能替代正式回执、GitHub LFS 冷下载或业务恢复。完整发布 reader 拒绝该记录。恢复时在副本运行 `toolkit/runtime/cli/win-x86/PbBridge.Cli.exe version` 和 `doctor`，审查原字节后由所有者决定工具包替换；不自动回退业务。升级或恢复后逐 workspace 重新生成 readonly-sync/export、baseline 和 V8 preflight。
