---
name: pbbridge-submodule-update
description: 当用户需要更新 PbBridge.Toolkit、pb-libs、pb-langchao 或其他 PowerBuilder 共享库 submodule，拉取子模块更新，刷新父仓库 submodule 指针，重新运行 pbbridge-readonly-sync、verify、report 或更新 baseline 时使用。
---

# PbBridge Submodule Update

使用本 skill 处理 toolkit 或 PowerBuilder 共享库 submodule 更新后的完整协作流程。目标是把“子模块 commit 变了”安全地落到消费项目当前 `.pbw/.pbt/LibList`、`.sr*` 事实源和 `.pbbridge/workspaces/default` baseline 上。

## 先判断 Git 边界

1. 在父仓库运行 `git status --short --branch` 和 `git submodule status --recursive`，确认目标 submodule 路径与当前指针。
2. 进入目标 submodule 后运行 `git status --short --branch`，若子模块内部有未提交修改，先停止更新并让用户决定是否提交、暂存或放弃。
3. 只更新用户指定的 submodule；用户只说“toolkit 更新”时，默认目标是 `.pbbridge/PbBridge.Toolkit` 或本仓库的 `Toolkit/PbBridge.Toolkit`。
4. 用户只说“pb-libs 更新”或“共享库更新”时，把 `pb-libs`、`pb-langchao` 等作为外部 PB 项目的典型 submodule 名称处理，先用 `.gitmodules` 或目录事实确认真实路径。
5. 子模块内部如果有未提交 `.sr*`、`.pbl` 或脚本修改，必须先完成子模块内提交或暂停，不要在父仓只提交指针。

## 更新流程

1. 在目标 submodule 中执行 fetch 或 pull 前，先报告当前分支、HEAD、远端和工作区状态。
2. 拉取后记录旧 commit 与新 commit；不要把“已拉取子模块”说成“父仓库已提交更新”。
3. 回到父仓库检查 `git status --short`，确认父仓库是否出现 submodule 指针变更。
4. 如果更新的是 `PbBridge.Toolkit`，优先阅读新的 `CODEX-START.md`、`manifest.json` 和相关 `skills/*/SKILL.md`，确认流程或模板是否变化。
5. 如果更新的是 `pb-libs` 等共享库，必须把消费项目 baseline 理解为“当前 `.pbw/.pbt` + 当前 submodule commit”的集成快照。

## Toolkit 最新快照检查

`PbBridge.Toolkit` 子仓从官方 GitHub main 连续历史分发，保留既有历史和版本 tag。判断 Toolkit 是否有更新时，只比较本地 submodule `HEAD` 与远端 `github/main`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-toolkit-update.ps1
```

默认检查只写出 `.pbbridge/toolkit-update-check.json` 并提示 `current/outdated/blocked`，不会更新工作树、不会 stage、不会提交。需要更新到远端最新快照时显式运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-toolkit-update.ps1 -Apply
```

`-Apply` 在工作区干净、原始 ZIP 恢复核验通过、目标 LFS OID/size/hash 与 checksum 验证完成后，checkout 绑定的精确目标 SHA，并后验实际字节；完成后必须回父项目提交 `.pbbridge/PbBridge.Toolkit` submodule 指针。显式 remote 别名须指向同一官方仓库。TargetCommit 可选 fetched main 或祖先，但拒绝回退/本地分叉；无共同祖先保留显式确认。WhatIf 不预取/切换。缓存匹配不证明独立 GitHub 下载。

## 共享库回灌流程

当父项目审查发现共享库对象需要修复时，先分类为“回灌共享库”“项目私有保留”或“废弃旧副本”。如果判定为回灌共享库，必须切换到共享库 submodule 工作区执行：

1. 在 submodule 内修改 `src/<normalized-pbl-name>/**/*.sr*` 和必要伴随文件。
2. 使用 `pbbridge-cli` 工作流完成 `verify / diff / shared-library gate / v4 import-object 或 import-objects DryRun / Apply --writeback --post-apply-review`；对象级写回使用 manifest 输出的路径化 `ObjectKey`，交接说明也写路径化 key。
3. 确认 submodule 内 `src`、对应 `.pbl`、post-apply review 或反导出证据一致。
4. 在 submodule 内提交并推送共享库修复，提交说明写明 PBL、对象、影响范围和验证证据。
5. 回父仓库只更新 submodule 指针和必要的 `.pbt/.pbw` 引用，再刷新消费项目 baseline。

禁止在父项目本地同名 PBL 副本中长期保存共享库修复，也不要只提交父仓指针而遗漏 submodule 内的共享库提交。

FastReport 类案例：父项目可以发现 `Lib_FastReport.pbl:userobject:nvo_fastreport` 或 `str_fr` 与 `pb-libs` 不一致，但实际修复必须进入 `pb-libs` submodule，按新版 DLL/demo 更新 `pb-libs/src/lib_fastreport/...`，写回 `pb-libs/Lib_FastReport.pbl` 并提交后，父项目再更新 `pb-libs` 指针。

## 刷新 PbBridge 状态

更新共享库 submodule 指针后，在消费项目根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-readonly-sync.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-check-shared-library-writeback.ps1 -SharedLibraryPath .\pb-libs -AllowPointerUpdate
```

若项目需要排除已有自己源码事实源的共享库，沿用项目既有参数，例如：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-readonly-sync.ps1 -ScanScope all-targets -ExcludeLibrary 'pb-libs/*','pb-langchao/*'
```

如果项目维护了 `.pbbridge/shared-libraries.json`，共享库检查脚本可以不传 `-SharedLibraryPath`，直接读取配置并输出聚合 JSON。配置必须显式列出共享库路径，不能让脚本隐式扫描全部 submodule：

```json
{
  "schemaName": "pbbridge-shared-library-config",
  "sharedLibraries": [
    {
      "name": "pb-libs",
      "path": "pb-libs",
      "parentOutputPath": ".pbbridge/workspaces/default/artifacts/pbbridge",
      "sharedOutputPath": "pb-libs/.pbbridge/workspaces/default/artifacts/pbbridge",
      "resultJsonPath": ".pbbridge/shared-library-writeback-check.pb-libs.json"
    }
  ]
}
```

缺少共享库配置时，2.8.0 起先运行初始化草案：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pbbridge-init-shared-libraries.ps1
```

草案会扫描 `.gitmodules`、共享库 `.pbw/.pbt` 和父项目 manifest：有独立 PBW/PBT 的共享库建议 `evidenceMode=self`，只有父项目 manifest 覆盖的共享库建议 `evidenceMode=consumer`。传 `-Apply` 写入 `.pbbridge/shared-libraries.json` 前必须人工复核；目标已存在时除非传 `-Force`，否则应保持失败。

检查脚本只生成证据，不提交、不推送、不更新 submodule 指针。配置在 `.pbbridge/shared-libraries.json` 中的共享库，专家链路 gate 通过后默认允许继续 Apply/WriteBack，不需要额外共享库写回授权；gate 失败、证据缺失或配置缺失仍必须阻断。`-AllowDirtySubmodule` 和 `-AllowPointerUpdate` 只把对应阻断降级为告警，仍保留 `submoduleCommit`、`parentRecordedCommit`、`issues[]` 和 `evidence[]`。

刷新后检查：

1. `.pbbridge/workspaces/default/artifacts/pbbridge/verify.json`
2. `.pbbridge/workspaces/default/artifacts/pbbridge/report.md`
3. `report` 的 Source Layout 与受管控 PBL 清单
4. 是否出现新的 `.sr*` 事实源变化或 baseline 变化
5. `.pbbridge/shared-library-writeback-check.json` 或每个共享库配置的 `resultJsonPath`
6. `.pbbridge/project-health.json`，缺失时建议运行 `scripts/pbbridge-project-health.ps1` 做更新后的统一总览

## 提交交接

1. 子模块内部如果产生了源码修改，使用 `pbbridge-git-publish` 在子模块内单独提交并推送。
2. 父仓库只提交 submodule 指针、必要的脚本或配置更新；不要提交 `.pbbridge/workspaces/`，也不要提交共享库本地同名 PBL 副本作为替代修复。
3. 若同步后 `.sr*` 有变化，先判断是共享库真实源码变化、消费项目导出布局变化，还是编译/导出噪声。
4. 回灌完成顺序必须是：子仓提交并推送 -> 父仓更新 submodule 指针 -> 父仓 readonly sync -> 父仓 verify/report。
5. 结束时说明：目标 submodule 的旧新 commit、父仓库指针是否变化、是否已运行 readonly sync、verify/report 是否通过、共享库 gate JSON 路径、仍需用户在 PowerBuilder IDE 中编译和运行验收。
6. 复杂任务按 `skills/_shared/handoff-template.md` 补齐 Git 状态和未完成风险。
7. 如果已运行 project-health，补充总体状态和仍需处理的 check issue code。

## 权威资料

- `CODEX-START.md`：启动、自检、submodule 与 baseline 规则。
- `skills/pbbridge-cli/SKILL.md`：export、verify、report、diff、import 的命令选择。
- `docs/getting-started/安装与升级说明.md`：toolkit 安装与升级说明。

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
