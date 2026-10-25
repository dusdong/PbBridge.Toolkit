#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.5.3
<#
.SYNOPSIS
检查或更新外部项目使用的 Toolkit 快照。
.DESCRIPTION
普通快进沿用受控更新；无共同祖先时必须选择刚 fetch 的远端分支头、通过契约校验并显式确认，才允许 detached HEAD 切换。
.PARAMETER TargetCommit
历史断代升级的目标提交，必须为 40 位提交并精确等于本次 fetch 的 Remote/Branch HEAD。
.PARAMETER AcknowledgeHistoryDiscontinuity
显式确认无共同祖先的历史断代切换；该开关不会放宽本地分叉保护。
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = "",
    [string]$ToolkitRoot = "",
    [ValidateNotNullOrEmpty()]
    [string]$Remote = "origin",
    [ValidateNotNullOrEmpty()]
    [string]$Branch = "master",
    [string]$ResultPath = "",
    [string]$TargetCommit = "",
    [string]$ReleaseRecordPath = "",
    [string]$PublicationReceiptPath = "",
    [string]$RecoveryArtifactRoot = "",
    [string]$RecoveryExtractionRoot = "",
    [switch]$AcknowledgeHistoryDiscontinuity,
    [switch]$Apply,
    [switch]$PassThru,
    [switch]$Help,
    [switch]$CliHelp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$wrapperModulePath = Join-Path $PSScriptRoot 'PbBridge.Wrapper.psm1'
if (-not (Test-Path -LiteralPath $wrapperModulePath -PathType Leaf)) {
    throw "未找到共享 wrapper module：$wrapperModulePath"
}
Import-Module $wrapperModulePath -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot 'PbBridge.ReleaseIdentity.psm1') -Force -ErrorAction Stop
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-toolkit-update.ps1" -CliCommand "pbbridge toolkit update"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @("toolkit", "update", "--help"); exit 0 }

function Resolve-TemplateToolkitRoot {
    param([string]$ExplicitRoot, [string]$ProjectRoot)
    if (-not [string]::IsNullOrWhiteSpace($ExplicitRoot)) {
        return [System.IO.Path]::GetFullPath($ExplicitRoot)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot ".pbbridge\PbBridge.Toolkit"))
}

function Invoke-ToolkitGit {
    param(
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    $result = Invoke-PbBridgeNativeCommand -FilePath "git" -Arguments (@("-C", $WorkingDirectory) + $Arguments) -WorkingDirectory $WorkingDirectory -Capture
    $stdout = ([string]$result.StdOut).Trim()
    $stderr = ([string]$result.StdErr).Trim()
    $text = (@($stdout, $stderr) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join [Environment]::NewLine
    return [pscustomobject]@{
        exitCode = $result.ExitCode
        text = $text
        stdout = $stdout
        stderr = $stderr
    }
}

function Read-ToolkitVersion {
    param([Parameter(Mandatory = $true)][string]$ToolkitRoot)
    $versionPath = Join-Path $ToolkitRoot "VERSION"
    if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
        return $null
    }
    return ([System.IO.File]::ReadAllText($versionPath, [System.Text.Encoding]::UTF8)).Trim()
}

function Read-ToolkitCommitText {
    param(
        [Parameter(Mandatory = $true)][string]$ToolkitRoot,
        [Parameter(Mandatory = $true)][string]$Commit,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $show = Invoke-ToolkitGit -WorkingDirectory $ToolkitRoot -Arguments @("show", ($Commit + ":" + $Path))
    if ($show.exitCode -ne 0) {
        throw "目标提交缺少或无法读取 $Path：$($show.text)"
    }
    return $show.stdout.Trim()
}

function Get-JsonStringProperty {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $null
    }
    return ([string]$property.Value).Trim()
}

function Test-ToolkitTargetContract {
    param(
        [Parameter(Mandatory = $true)][string]$ToolkitRoot,
        [Parameter(Mandatory = $true)][string]$Commit
    )
    try {
        $version = Read-ToolkitCommitText -ToolkitRoot $ToolkitRoot -Commit $Commit -Path "VERSION"
        $manifest = Read-ToolkitCommitText -ToolkitRoot $ToolkitRoot -Commit $Commit -Path "manifest.json" | ConvertFrom-Json -ErrorAction Stop
        $runtime = Read-ToolkitCommitText -ToolkitRoot $ToolkitRoot -Commit $Commit -Path "checks/toolkit-runtime-contract.json" | ConvertFrom-Json -ErrorAction Stop
        $template = Read-ToolkitCommitText -ToolkitRoot $ToolkitRoot -Commit $Commit -Path "templates/external-project/template-manifest.json" | ConvertFrom-Json -ErrorAction Stop
        $manifestRuntime = $manifest.PSObject.Properties["runtimeContract"]
        $versions = [ordered]@{
            version = $version
            manifestToolkitVersion = Get-JsonStringProperty -Object $manifest -Name "toolkitVersion"
            manifestProductVersion = Get-JsonStringProperty -Object $manifest -Name "productVersion"
            manifestTemplateVersion = Get-JsonStringProperty -Object $manifest -Name "externalProjectTemplateVersion"
            manifestDoctorVersion = if ($null -eq $manifestRuntime -or $null -eq $manifestRuntime.Value) { $null } else { Get-JsonStringProperty -Object $manifestRuntime.Value -Name "cliDoctorContractVersion" }
            runtimeToolkitVersion = Get-JsonStringProperty -Object $runtime -Name "toolkitVersion"
            runtimeDoctorVersion = Get-JsonStringProperty -Object $runtime -Name "cliDoctorContractVersion"
            templateVersion = Get-JsonStringProperty -Object $template -Name "templateVersion"
        }
        $invalid = @($versions.GetEnumerator() | Where-Object {
            [string]::IsNullOrWhiteSpace([string]$_.Value) -or -not ([string]$_.Value).Equals($version, [StringComparison]::Ordinal)
        })
        return [pscustomobject]@{
            valid = $invalid.Count -eq 0
            commit = $Commit
            version = $version
            versions = [pscustomobject]$versions
            invalidFields = @($invalid | ForEach-Object { $_.Key })
            summaryText = if ($invalid.Count -eq 0) {
                "目标 Toolkit 的 VERSION、manifest、runtime contract 与 template manifest 版本一致。"
            }
            else {
                "目标 Toolkit 契约版本不一致：$(@($invalid | ForEach-Object { $_.Key }) -join ', ')。"
            }
        }
    }
    catch {
        return [pscustomobject]@{
            valid = $false
            commit = $Commit
            version = $null
            versions = $null
            invalidFields = @("contract-read")
            summaryText = $_.Exception.Message
        }
    }
}

function Get-ToolkitHistoryRelation {
    param(
        [Parameter(Mandatory = $true)][string]$ToolkitRoot,
        [Parameter(Mandatory = $true)][string]$LocalCommit,
        [Parameter(Mandatory = $true)][string]$RemoteCommit
    )
    if ($LocalCommit.Equals($RemoteCommit, [StringComparison]::OrdinalIgnoreCase)) {
        return "fast-forward"
    }
    $ancestor = Invoke-ToolkitGit -WorkingDirectory $ToolkitRoot -Arguments @("merge-base", "--is-ancestor", $LocalCommit, $RemoteCommit)
    if ($ancestor.exitCode -eq 0) {
        return "fast-forward"
    }
    $mergeBase = Invoke-ToolkitGit -WorkingDirectory $ToolkitRoot -Arguments @("merge-base", $LocalCommit, $RemoteCommit)
    if ($mergeBase.exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($mergeBase.stdout)) {
        return "diverged"
    }
    return "unrelated"
}

function New-ToolkitUpdateIssue {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][string]$Severity,
        [Parameter(Mandatory = $true)][string]$Message
    )
    return [pscustomobject]@{ code = $Code; severity = $Severity; message = $Message }
}

function New-ToolkitUpdateResult {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$ToolkitRoot,
        [Parameter(Mandatory = $true)][string]$Remote,
        [Parameter(Mandatory = $true)][string]$Branch,
        [string]$PreviousCommit,
        [string]$LocalCommit,
        [string]$RemoteCommit,
        [string]$LocalVersion,
        [string]$RemoteVersion,
        [string]$HistoryRelation,
        [string]$RemoteUrl,
        [string]$RequestedTargetCommit,
        [string]$VerifiedTargetCommit,
        [object]$TargetValidation,
        [string]$RecoveryCommand,
        [object[]]$Issues = @(),
        [string[]]$NextActions = @()
    )
    return [pscustomobject]@{
        schemaName = "pbbridge-toolkit-update-check"
        generatedAt = [DateTimeOffset]::Now.ToString("o")
        status = $Status
        projectRoot = $ProjectRoot
        toolkitRoot = $ToolkitRoot
        remote = $Remote
        branch = $Branch
        remoteRef = "refs/remotes/$Remote/$Branch"
        remoteUrl = $RemoteUrl
        previousCommit = $PreviousCommit
        localCommit = $LocalCommit
        remoteCommit = $RemoteCommit
        requestedTargetCommit = $RequestedTargetCommit
        verifiedTargetCommit = $VerifiedTargetCommit
        historyRelation = $HistoryRelation
        localVersion = $LocalVersion
        remoteVersion = $RemoteVersion
        targetValidation = $TargetValidation
        previousBuild = $previousBuild
        targetBuild = $targetBuild
        recovery = $recovery
        recoveryScope = 'toolkit-only'
        requiresCurrentFacts = $true
        recoveryCommand = $RecoveryCommand
        apply = $Apply.IsPresent
        historyDiscontinuityAcknowledged = $AcknowledgeHistoryDiscontinuity.IsPresent
        issues = @($Issues)
        nextActions = @($NextActions)
    }
}

function Write-ToolkitUpdateResult {
    param(
        [Parameter(Mandatory = $true)][object]$Result,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $Result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding utf8
}

$projectRootFull = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot
$toolkitRootFull = Resolve-TemplateToolkitRoot -ExplicitRoot $ToolkitRoot -ProjectRoot $projectRootFull
$resultPathFull = if ([string]::IsNullOrWhiteSpace($ResultPath)) {
    [System.IO.Path]::GetFullPath((Join-Path $projectRootFull ".pbbridge\toolkit-update-check.json"))
}
elseif ([System.IO.Path]::IsPathRooted($ResultPath)) {
    [System.IO.Path]::GetFullPath($ResultPath)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $projectRootFull $ResultPath))
}

$issues = @()
$nextActions = @()
$previousCommit = $null
$localCommit = $null
$remoteCommit = $null
$localVersion = $null
$remoteVersion = $null
$historyRelation = $null
$remoteUrl = $null
$verifiedTargetCommit = $null
$targetValidation = $null
$recoveryCommand = $null
$status = "blocked"
$previousBuild = $null
$targetBuild = $null
$recovery = [pscustomobject]@{status='unavailable';reasonCode='recovery-original-artifact-not-provided';recoveryScope='toolkit-only';requiresCurrentFacts=$true}
$remoteRef = "refs/remotes/$Remote/$Branch"

try {
    if (-not (Test-Path -LiteralPath $toolkitRootFull -PathType Container)) {
        $issues += New-ToolkitUpdateIssue -Code "toolkit-submodule-missing" -Severity "error" -Message "未找到 Toolkit submodule：$toolkitRootFull"
        $nextActions += "先以 submodule 方式引入 .pbbridge/PbBridge.Toolkit。"
    }
    else {
        $inside = Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @("rev-parse", "--is-inside-work-tree")
        if ($inside.exitCode -ne 0 -or $inside.text -ne "true") {
            $issues += New-ToolkitUpdateIssue -Code "toolkit-not-git-worktree" -Severity "error" -Message "Toolkit 路径不是 Git 工作区：$toolkitRootFull"
            $nextActions += "确认 .pbbridge/PbBridge.Toolkit 是 Git submodule，而不是普通目录拷贝。"
        }
        else {
            $localHead = Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @("rev-parse", "HEAD")
            if ($localHead.exitCode -eq 0) {
                $localCommit = $localHead.stdout
                $previousCommit = $localCommit
            }
            $localVersion = Read-ToolkitVersion -ToolkitRoot $toolkitRootFull
            $fetchRefSpec = "+refs/heads/" + $Branch + ":refs/remotes/" + $Remote + "/" + $Branch
            $fetch = Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @("fetch", $Remote, $fetchRefSpec, "--prune")
            if ($fetch.exitCode -ne 0) {
                $status = "fetch-failed"
                $issues += New-ToolkitUpdateIssue -Code "toolkit-fetch-failed" -Severity "warning" -Message "无法获取远端 Toolkit 快照：$($fetch.text)"
                $nextActions += "确认网络、远端名 $Remote 和分支 $Branch 可访问后重新运行本脚本。"
            }
            else {
                $remoteHead = Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @("rev-parse", $remoteRef)
                $remoteUrlResult = Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @("remote", "get-url", $Remote)
                if ($remoteUrlResult.exitCode -eq 0) {
                    $remoteUrl = $remoteUrlResult.stdout
                }
                if ($remoteHead.exitCode -ne 0) {
                    $issues += New-ToolkitUpdateIssue -Code "toolkit-remote-ref-missing" -Severity "error" -Message "未找到远端快照引用：$remoteRef"
                    $nextActions += "确认 Toolkit 远端存在 $Branch 分支。"
                }
                else {
                    $remoteCommit = $remoteHead.stdout
                    $remoteVersionResult = Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @("show", ($remoteCommit + ":VERSION"))
                    if ($remoteVersionResult.exitCode -eq 0) {
                        $remoteVersion = $remoteVersionResult.stdout
                    }
                    $historyRelation = Get-ToolkitHistoryRelation -ToolkitRoot $toolkitRootFull -LocalCommit $localCommit -RemoteCommit $remoteCommit
                    $previousBuild = Get-PbToolkitSnapshotIdentity -ToolkitPath $toolkitRootFull -Commit $localCommit
                    $targetBuild = Get-PbToolkitSnapshotIdentity -ToolkitPath $toolkitRootFull -Commit $remoteCommit
                    if ($ReleaseRecordPath -and $RecoveryArtifactRoot -and $RecoveryExtractionRoot) {
                        $recovery = Get-PbReleaseRecoveryPreview -RecordPath $ReleaseRecordPath -PublicationReceiptPath $PublicationReceiptPath -ArtifactRoot $RecoveryArtifactRoot -ExtractionRoot $RecoveryExtractionRoot
                        if ($recovery.status -eq 'verified') {
                            foreach ($field in @('productVersion','cliSha256','toolkitCommit','runtimeContractSha256','manifestSha256')) {
                                if ([string]$recovery.identity[$field] -cne [string]$previousBuild.identity.$field) {
                                    $recovery.status='unavailable';$recovery.reasonCode="recovery-local-identity-mismatch:$field"
                                }
                            }
                        }
                    }
                    $nextActions += '升级后逐 workspace 重新生成 readonly-sync/export、baseline 和 V8 preflight；保留冲突及定制。工具包恢复不恢复 PBL、源码或 session。'
                    $branchName = Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @("branch", "--show-current")
                    $isDetachedHead = $branchName.exitCode -eq 0 -and [string]::IsNullOrWhiteSpace($branchName.stdout)
                    $worktreeStatus = Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @("status", "--porcelain=v1", "--untracked-files=all")
                    $worktreeDirty = $worktreeStatus.exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($worktreeStatus.stdout)

                    if ($worktreeStatus.exitCode -ne 0) {
                        $issues += New-ToolkitUpdateIssue -Code "toolkit-status-failed" -Severity "error" -Message "无法检查 Toolkit 工作区状态：$($worktreeStatus.text)"
                        $nextActions += "先手工检查 Toolkit submodule 状态。"
                    }
                    elseif ($worktreeDirty) {
                        $status = "dirty-submodule"
                        $issues += New-ToolkitUpdateIssue -Code "toolkit-worktree-dirty" -Severity "error" -Message "Toolkit submodule 内存在未提交修改，已拒绝自动更新。"
                        $nextActions += "先处理 .pbbridge/PbBridge.Toolkit 内部修改，再重新运行。"
                    }
                    elseif ($localCommit -eq $remoteCommit) {
                        $status = if ($isDetachedHead) { "detached-head-current" } else { "current" }
                        $nextActions += "Toolkit 已是远端 $Remote/$Branch 最新快照。"
                    }
                    elseif ($historyRelation -eq "diverged") {
                        $status = "non-fast-forward-local"
                        $issues += New-ToolkitUpdateIssue -Code "toolkit-non-fast-forward-local" -Severity "error" -Message "本地 Toolkit HEAD 与远端存在共同祖先但已经分叉，禁止丢弃本地提交。"
                        $nextActions += "保留本地分支，手工审查 Toolkit 本地提交与远端快照差异。"
                    }
                    elseif ($historyRelation -eq "fast-forward") {
                        if ($Apply.IsPresent -and $recovery.status -ne 'verified') {
                            $status='blocked'
                            $issues += New-ToolkitUpdateIssue -Code 'toolkit-recovery-unverified' -Severity error -Message $recovery.reasonCode
                            $nextActions += '提供旧发行树外记录、原始制品渠道与新的隔离恢复目录，核验旧完整身份及入口后再切换。'
                        }
                        elseif (-not $Apply.IsPresent) {
                            $status = "outdated"
                            $issues += New-ToolkitUpdateIssue -Code "toolkit-snapshot-outdated" -Severity "warning" -Message "本地 Toolkit 快照落后远端 $Remote/$Branch。"
                            $nextActions += "运行 scripts/pbbridge-toolkit-update.ps1 -Apply 更新 Toolkit submodule 工作树。"
                        }
                        elseif ($PSCmdlet.ShouldProcess($toolkitRootFull, "Checkout Toolkit snapshot $remoteCommit")) {
                            $checkout = Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @("checkout", "-B", $Branch, $remoteRef)
                            if ($checkout.exitCode -ne 0) {
                                $issues += New-ToolkitUpdateIssue -Code "toolkit-checkout-failed" -Severity "error" -Message "更新 Toolkit 快照失败：$($checkout.text)"
                                $nextActions += "手工进入 Toolkit submodule 检查 git checkout 失败原因。"
                            }
                            else {
                                $localCommit = $remoteCommit
                                $localVersion = Read-ToolkitVersion -ToolkitRoot $toolkitRootFull
                                $status = "updated"
                                $nextActions += "Toolkit 已更新到远端 $Remote/$Branch 最新快照。"
                                $nextActions += "回到父项目检查并提交 .pbbridge/PbBridge.Toolkit submodule 指针。"
                            }
                        }
                        else {
                            $status = "outdated"
                        }
                    }
                    else {
                        $status = "history-discontinuity"
                        $issues += New-ToolkitUpdateIssue -Code "toolkit-history-discontinuity" -Severity "warning" -Message "本地 Toolkit HEAD 与刚获取的远端分支头没有共同祖先。"
                        if ([string]::IsNullOrWhiteSpace($TargetCommit)) {
                            $issues += New-ToolkitUpdateIssue -Code "toolkit-target-commit-required" -Severity "error" -Message "历史断代升级必须显式提供刚获取的远端分支头 TargetCommit。"
                            $nextActions += "审查远端分支头后，以 -TargetCommit <40-hex> 重新运行预检。"
                        }
                        elseif ($TargetCommit -notmatch '^[0-9a-fA-F]{40}$' -or -not $TargetCommit.Equals($remoteCommit, [StringComparison]::OrdinalIgnoreCase)) {
                            $issues += New-ToolkitUpdateIssue -Code "toolkit-target-not-remote-head" -Severity "error" -Message "TargetCommit 必须精确等于本次 fetch 的 $Remote/$Branch 头 $remoteCommit。"
                            $nextActions += "不要使用任意本地或历史 commit；重新读取本次结果的 remoteCommit。"
                        }
                        else {
                            $targetValidation = Test-ToolkitTargetContract -ToolkitRoot $toolkitRootFull -Commit $remoteCommit
                            if (-not $targetValidation.valid) {
                                $issues += New-ToolkitUpdateIssue -Code "toolkit-target-contract-invalid" -Severity "error" -Message $targetValidation.summaryText
                                $nextActions += "修复远端 Toolkit VERSION、manifest、runtime contract 与 template manifest 的版本一致性。"
                            }
                            else {
                                $verifiedTargetCommit = $remoteCommit
                                $recoveryCommand = if ($recovery.status -eq 'verified') { '使用 recovery.extractedToolkit 中经核验的原始工具包；重新生成当前 facts，禁止迁移旧 session。' } else { $null }
                                if ($recovery.status -ne 'verified') {
                                    $status='blocked'
                                    $issues += New-ToolkitUpdateIssue -Code 'toolkit-recovery-unverified' -Severity error -Message $recovery.reasonCode
                                    $nextActions += '原始旧制品恢复未验证，禁止自动快照切换；源码可重建或旧 commit 不能代替原包。'
                                }
                                elseif (-not $Apply.IsPresent -or $WhatIfPreference) {
                                    $status = "history-switch-ready"
                                    $nextActions += "确认目标契约与恢复命令后，同时提供 -Apply 与 -AcknowledgeHistoryDiscontinuity 执行切换。"
                                }
                                elseif (-not $AcknowledgeHistoryDiscontinuity.IsPresent) {
                                    $status = "history-discontinuity"
                                    $issues += New-ToolkitUpdateIssue -Code "toolkit-history-ack-required" -Severity "error" -Message "Apply 历史断代切换必须显式确认 AcknowledgeHistoryDiscontinuity。"
                                    $nextActions += "审查 targetValidation 和 recoveryCommand 后再显式确认。"
                                }
                                elseif ($PSCmdlet.ShouldProcess($toolkitRootFull, "Detach Toolkit HEAD at verified remote snapshot $remoteCommit")) {
                                    $checkout = Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @("checkout", "--detach", $remoteCommit)
                                    if ($checkout.exitCode -ne 0) {
                                        $issues += New-ToolkitUpdateIssue -Code "toolkit-checkout-failed" -Severity "error" -Message "历史断代切换失败：$($checkout.text)"
                                        $nextActions += "保持原分支不动，按 recoveryCommand 返回 previousCommit。"
                                    }
                                    else {
                                        $localCommit = $remoteCommit
                                        $localVersion = Read-ToolkitVersion -ToolkitRoot $toolkitRootFull
                                        $status = "history-switched"
                                        $nextActions += "Toolkit 已以 detached HEAD 切换到经验证的远端快照。"
                                        $nextActions += "回到父项目审查并提交 .pbbridge/PbBridge.Toolkit submodule 指针。"
                                    }
                                }
                                else {
                                    $status = "history-switch-ready"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
catch {
    $issues += New-ToolkitUpdateIssue -Code "toolkit-update-exception" -Severity "error" -Message $_.Exception.Message
    $nextActions += "保留当前 Toolkit 工作区，排查异常后重新运行本脚本。"
}

$resultArguments = @{
    Status = $status
    ProjectRoot = $projectRootFull
    ToolkitRoot = $toolkitRootFull
    Remote = $Remote
    Branch = $Branch
    PreviousCommit = $previousCommit
    LocalCommit = $localCommit
    RemoteCommit = $remoteCommit
    LocalVersion = $localVersion
    RemoteVersion = $remoteVersion
    HistoryRelation = $historyRelation
    RemoteUrl = $remoteUrl
    RequestedTargetCommit = $TargetCommit
    VerifiedTargetCommit = $verifiedTargetCommit
    TargetValidation = $targetValidation
    RecoveryCommand = $recoveryCommand
    Issues = $issues
    NextActions = $nextActions
}
$result = New-ToolkitUpdateResult @resultArguments
Write-ToolkitUpdateResult -Result $result -Path $resultPathFull

if ($result.status -in @("outdated", "history-discontinuity", "history-switch-ready")) {
    Write-Warning "Toolkit update status: $($result.status)。请检查结果文件 $resultPathFull。"
}
elseif ($result.status -eq "blocked") {
    Write-Warning "Toolkit 更新检查未通过：$(@($result.issues | ForEach-Object { $_.message }) -join '; ')"
}
else {
    Write-Verbose -Message ("Toolkit update status: {0}" -f $result.status)
}

if ($PassThru.IsPresent) {
    Write-Output -NoEnumerate $result
}
