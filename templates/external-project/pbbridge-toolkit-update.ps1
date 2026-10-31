#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.1
<#
.SYNOPSIS
检查或更新外部项目使用的 Toolkit 快照。
.DESCRIPTION
普通快进沿用受控更新；无共同祖先时必须选择刚 fetch 的远端分支头、通过契约校验并显式确认，才允许 detached HEAD 切换。
.PARAMETER TargetCommit
目标提交，必须为本次 fetch 的官方 main 本身或祖先的 40 位 SHA；不得回退或丢弃本地分叉。
.PARAMETER RecoveryPurpose
CompleteQualification（默认）要求完整发布材料；HistoricalRecovery 使用 7.5.3 原 ZIP。
InstalledCandidateRecovery 仅允许清洁 7.6.0 候选到 7.6.1 普通快进，须提供 ToolkitRoot 和树外 RecoveryExtractionRoot；禁止混入发布 record/receipt/artifact 参数。
WhatIf 可实际准备并验证显式副本及写 ResultPath，但不会切换安装。
.PARAMETER AcknowledgeHistoryDiscontinuity
显式确认无共同祖先的历史断代切换；该开关不会放宽本地分叉保护。
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = "",
    [string]$ToolkitRoot = "",
    [ValidateNotNullOrEmpty()]
    [string]$Remote = "github",
    [ValidateNotNullOrEmpty()]
    [string]$Branch = "main",
    [string]$ResultPath = "",
    [string]$TargetCommit = "",
    [string]$ReleaseRecordPath = "",
    [string]$PublicationReceiptPath = "",
    [string]$RecoveryArtifactRoot = "",
    [string]$RecoveryExtractionRoot = "",
    [ValidateSet('CompleteQualification','HistoricalRecovery','InstalledCandidateRecovery')]
    [string]$RecoveryPurpose = 'CompleteQualification',
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
if ($Help.IsPresent) {
    Show-PbBridgeWrapperHelp -WrapperName "pbbridge-toolkit-update.ps1" -CliCommand "pbbridge toolkit update"
    Get-Help $PSCommandPath -Detailed
    exit 0
}
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

function Test-ToolkitOfficialUrl {
    param([string]$Url)
    return $Url -cmatch '\A(?:https://github\.com/dusdong/PbBridge\.Toolkit(?:\.git)?|git@github\.com:dusdong/PbBridge\.Toolkit(?:\.git)?|ssh://git@github\.com/dusdong/PbBridge\.Toolkit(?:\.git)?)\z'
}

function Test-ToolkitParentSource {
    param([string]$Root)
    # A standalone clone has no selected gitlink/configuration to migrate.
    $parent = Invoke-ToolkitGit -WorkingDirectory (Split-Path -Parent $Root) -Arguments @('rev-parse','--show-toplevel')
    if ($parent.exitCode -ne 0) { return }
    $parentRoot = [IO.Path]::GetFullPath($parent.stdout)
    $relative = [IO.Path]::GetRelativePath($parentRoot,$Root).Replace('\','/')
    $gitlink = Invoke-ToolkitGit -WorkingDirectory $parentRoot -Arguments @('ls-files','--stage','--',$relative)
    if ($gitlink.exitCode -ne 0) { throw 'toolkit-parent-index-unavailable' }
    $paths = Invoke-ToolkitGit -WorkingDirectory $parentRoot -Arguments @('config','--file','.gitmodules','--get-regexp','^submodule\..*\.path$')
    if ($paths.exitCode -notin @(0,1)) { throw 'toolkit-parent-gitmodules-invalid' }
    $selected = @()
    foreach ($line in ($paths.stdout -split '\r?\n')) {
        if ($line -match '^(submodule\..+)\.path (.+)$') {
            $key=$Matches[1]; $path=$Matches[2]
            if ([IO.Path]::GetFullPath((Join-Path $parentRoot $path)).Equals([IO.Path]::GetFullPath($Root),[StringComparison]::OrdinalIgnoreCase)) { $selected += $key }
        }
    }
    if ($selected.Count -eq 0 -and $gitlink.stdout -notmatch '^160000 ') { return }
    if ($selected.Count -ne 1) { throw 'toolkit-parent-submodule-identity-ambiguous' }
    $key=$selected[0]+'.url'
    $declared = Invoke-ToolkitGit -WorkingDirectory $parentRoot -Arguments @('config','--file','.gitmodules','--get-all',$key)
    $local = Invoke-ToolkitGit -WorkingDirectory $parentRoot -Arguments @('config','--local','--get-all',$key)
    if ($declared.exitCode -ne 0 -or $local.exitCode -ne 0 -or
        -not (Test-ToolkitOfficialUrl $declared.stdout) -or -not (Test-ToolkitOfficialUrl $local.stdout)) {
        throw 'toolkit-parent-submodule-source-not-official-or-ambiguous'
    }
}

function Get-ToolkitDownloadEnvironment {
    param([string]$Root)
    $url = Invoke-ToolkitGit -WorkingDirectory $Root -Arguments @('remote','get-url','--all',$Remote)
    if ($Branch -cne 'main' -or $url.exitCode -ne 0 -or
        -not (Test-ToolkitOfficialUrl $url.stdout)) {
        throw 'toolkit-source-not-official-main'
    }
    if (Test-Path -LiteralPath (Join-Path $Root '.lfsconfig')) { throw 'toolkit-lfsconfig-unsupported' }
    $environment = Invoke-ToolkitGit -WorkingDirectory $Root -Arguments @('-c',"remote.lfsdefault=$Remote",'lfs','env')
    if ($environment.exitCode -ne 0) { throw 'toolkit-lfs-environment-unavailable' }
    $endpoints = @($environment.stdout -split '\r?\n' | Where-Object { $_ -match '^Endpoint(?: \(.+\))?=' })
    $selected = @($endpoints | Where-Object { $_ -match ('^Endpoint(?: \(' + [regex]::Escape($Remote) + '\))?=') })
    if ($selected.Count -eq 0 -or @($selected | Where-Object { $_ -cnotmatch '^Endpoint(?: \(.+\))?=https://github\.com/dusdong/PbBridge\.Toolkit(?:\.git)?/info/lfs(?: \(auth=\w+\))?$' }).Count) {
        throw 'toolkit-lfs-download-source-not-official'
    }
    $media = [regex]::Match($environment.stdout,'(?m)^LocalMediaDir=(.+)\r?$').Groups[1].Value.Trim()
    if (-not $media -or -not [IO.Path]::IsPathRooted($media)) { throw 'toolkit-lfs-cache-unavailable' }
    return [pscustomobject]@{url=$url.stdout;media=$media}
}

function Save-ToolkitTargetLfs {
    param([string]$Root,[string]$Commit)
    $environment=Get-ToolkitDownloadEnvironment -Root $Root
    $listing=Invoke-ToolkitGit -WorkingDirectory $Root -Arguments @('lfs','ls-files','--json',$Commit)
    if ($listing.exitCode -ne 0) { throw 'toolkit-lfs-list-failed' }
    # Git LFS reports files=null for a target without LFS objects.
    $files=@(($listing.stdout | ConvertFrom-Json).files | Where-Object { $null -ne $_ })
    $checksums=Read-ToolkitCommitText -ToolkitRoot $Root -Commit $Commit -Path 'checks/SHA256SUMS.txt'
    $missingBytes=[long]0
    foreach ($file in $files) {
        if ($file.oid_type -cne 'sha256' -or $file.oid -cnotmatch '^[0-9a-f]{64}$' -or $file.size -lt 0) { throw 'toolkit-lfs-pointer-invalid' }
        $entry= '(?m)^'+[regex]::Escape($file.oid)+'  '+[regex]::Escape($file.name)+'\r?$'
        if ($checksums -cnotmatch $entry) { throw 'toolkit-lfs-checksum-manifest-mismatch' }
        $path=Join-Path $environment.media ($file.oid.Substring(0,2)+'/'+$file.oid.Substring(2,2)+'/'+$file.oid)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $missingBytes += [long]$file.size }
    }
    # Clear include/exclude filters so every object of the bound target is fetched.
    $fetch=Invoke-ToolkitGit -WorkingDirectory $Root -Arguments @('-c',"remote.lfsdefault=$Remote",'lfs','fetch','--include=','--exclude=',$Remote,$Commit)
    if ($fetch.exitCode -ne 0) { throw "toolkit-lfs-prefetch-failed (missingBytes=$missingBytes); installation retained" }
    foreach ($file in $files) {
        $path=Join-Path $environment.media ($file.oid.Substring(0,2)+'/'+$file.oid.Substring(2,2)+'/'+$file.oid)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -ne [long]$file.size -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $file.oid) { throw 'toolkit-lfs-cache-integrity-failed; installation retained' }
    }
    return [pscustomobject]@{objectCount=$files.Count;missingBytes=$missingBytes;cache=$environment.media;source='local-cache-and-explicit-fetch; independent GitHub download not proven'}
}

function Test-ToolkitInstalledContent {
    param([string]$Root,[string]$Commit)
    $contract=Test-ToolkitTargetContract -ToolkitRoot $Root -Commit $Commit
    if (-not $contract.valid) { throw $contract.summaryText }
    foreach ($line in ((Read-ToolkitCommitText -ToolkitRoot $Root -Commit $Commit -Path 'checks/SHA256SUMS.txt') -split '\r?\n')) {
        if ($line -cnotmatch '^([0-9a-f]{64})  (.+)$') { throw 'toolkit-checksum-invalid' }
        $hash=$Matches[1];$relative=$Matches[2]
        if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|/)\.\.?(/|$)|[\\:*?\x00-\x1f]') { throw 'toolkit-checksum-path-invalid' }
        $path=Join-Path $Root $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hash) { throw "toolkit-installed-checksum-mismatch:$relative" }
    }
    if ((Read-ToolkitVersion -ToolkitRoot $Root) -cne $contract.version) { throw 'toolkit-installed-version-mismatch' }
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
        lfsPrefetch = $lfsPrefetch
        previousBuild = $previousBuild
        targetBuild = $targetBuild
        recovery = $recovery
        recoveryPurpose = $RecoveryPurpose
        recoveryScope = 'toolkit-only'
        requiresCurrentFacts = $true
        recoveryCommand = $RecoveryCommand
        apply = $Apply.IsPresent
        historyDiscontinuityAcknowledged = $AcknowledgeHistoryDiscontinuity.IsPresent
        issues = @($Issues)
        nextActions = @($NextActions)
    }
}

function Assert-ToolkitUpdateResultPath {
    param([string]$Path)
    # The project is a protected input boundary. Only its dedicated updater
    # report is writable; custom reports belong in an independent task directory.
    $full=[IO.Path]::GetFullPath($Path)
    $default=[IO.Path]::GetFullPath((Join-Path $projectRootFull '.pbbridge/toolkit-update-check.json'))
    $gitDirectories=@(foreach ($repository in @($projectRootFull,$toolkitRootFull)) {
        if (Test-Path -LiteralPath $repository -PathType Container) {
            $resolved=Invoke-ToolkitGit -WorkingDirectory $repository -Arguments @('rev-parse','--path-format=absolute','--git-dir','--git-common-dir')
            if ($resolved.exitCode -eq 0) { $resolved.stdout -split '\r?\n' }
        }
    })
    foreach ($protected in @($toolkitRootFull,$RecoveryExtractionRoot)+$gitDirectories) {
        if (-not $protected) { continue }
        $protected=[IO.Path]::GetFullPath($protected).TrimEnd('\','/')
        if ($full.Equals($protected,[StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($protected+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $protected.StartsWith($full+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'toolkit-result-path-protected' }
    }
    if (($full.Equals($projectRootFull,[StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($projectRootFull.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) -and -not $full.Equals($default,[StringComparison]::OrdinalIgnoreCase)) { throw 'toolkit-result-path-project-input' }
    if ($full -match '(?i)(^|[\\/])\.git([\\/]|$)' -or [IO.Path]::GetExtension($full) -ine '.json') { throw 'toolkit-result-path-invalid' }
    # Get-Item also observes dangling links; Test-Path alone would miss a
    # result-file symlink whose protected target does not exist yet.
    $current=$full
    while ($current) {
        try { $item=Get-Item -LiteralPath $current -Force -ErrorAction Stop }
        catch [System.Management.Automation.ItemNotFoundException] { $item=$null }
        if ($null -ne $item) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'CANDIDATE_REPARSE_PATH' }
            if ($item.LinkType) { throw 'toolkit-result-path-link' }
        }
        $parent=Split-Path -Parent $current
        if ($parent -eq $current) { break };$current=$parent
    }
    if (Test-Path -LiteralPath $full) {
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw 'toolkit-result-path-not-file' }
        if ((Get-Item -LiteralPath $full -Force).LinkType) { throw 'toolkit-result-path-link' }
        # Existing query reports can be refreshed; arbitrary original JSON is
        # not an updater output, even when it is outside the project tree.
        try { $previous=Get-Content -LiteralPath $full -Raw -Encoding utf8|ConvertFrom-Json }
        catch { throw 'toolkit-result-path-occupied' }
        if (-not $previous.PSObject.Properties['schemaName'] -or $previous.schemaName -cne 'pbbridge-toolkit-update-check') { throw 'toolkit-result-path-occupied' }
    }
}

function Write-ToolkitUpdateResult {
    param(
        [Parameter(Mandatory = $true)][object]$Result,
        [Parameter(Mandatory = $true)][string]$Path
    )
    Assert-ToolkitUpdateResultPath -Path $Path
    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        $null=[IO.Directory]::CreateDirectory($parent)
    }
    [IO.File]::WriteAllText($Path,($Result | ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($false))
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

# Validate outside the workflow catch: an invalid output must never be used to
# write its own exception summary. Repeat at the actual write boundary as well.
Assert-ToolkitUpdateResultPath -Path $resultPathFull

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
$lfsPrefetch = $null
$recoveryCommand = $null
$status = "blocked"
$previousBuild = $null
$targetBuild = $null
$recovery = [pscustomobject]@{status='unavailable';reasonCode='recovery-original-artifact-not-provided';recoveryScope='toolkit-only';requiresCurrentFacts=$true}
$remoteRef = "refs/remotes/$Remote/$Branch"

try {
    if ($RecoveryPurpose -ceq 'InstalledCandidateRecovery' -and
        ($ReleaseRecordPath -or $PublicationReceiptPath -or $RecoveryArtifactRoot -or -not $RecoveryExtractionRoot -or -not $ToolkitRoot -or $AcknowledgeHistoryDiscontinuity)) {
        throw 'candidate-recovery-parameters-invalid: use ToolkitRoot and tree-external RecoveryExtractionRoot only'
    }
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
            Test-ToolkitParentSource -Root $toolkitRootFull
            $downloadEnvironment = Get-ToolkitDownloadEnvironment -Root $toolkitRootFull
            $remoteUrl = $downloadEnvironment.url
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
                    if ($TargetCommit) {
                        if ($TargetCommit -notmatch '^[0-9a-fA-F]{40}$') { throw 'toolkit-target-commit-invalid' }
                        $ancestor=Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @('merge-base','--is-ancestor',$TargetCommit,$remoteCommit)
                        if ($ancestor.exitCode -ne 0) { throw 'toolkit-target-not-fetched-main-ancestor' }
                        $remoteCommit=$TargetCommit.ToLowerInvariant()
                    }
                    $verifiedTargetCommit=$remoteCommit
                    $targetValidation=Test-ToolkitTargetContract -ToolkitRoot $toolkitRootFull -Commit $remoteCommit
                    if (-not $targetValidation.valid) { throw $targetValidation.summaryText }
                    $remoteVersionResult = Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @("show", ($remoteCommit + ":VERSION"))
                    if ($remoteVersionResult.exitCode -eq 0) {
                        $remoteVersion = $remoteVersionResult.stdout
                    }
                    $historyRelation = Get-ToolkitHistoryRelation -ToolkitRoot $toolkitRootFull -LocalCommit $localCommit -RemoteCommit $remoteCommit
                    $previousBuild = Get-PbToolkitSnapshotIdentity -ToolkitPath $toolkitRootFull -Commit $localCommit
                    $targetBuild = Get-PbToolkitSnapshotIdentity -ToolkitPath $toolkitRootFull -Commit $remoteCommit
                    if ($RecoveryPurpose -ceq 'InstalledCandidateRecovery') {
                        if ($historyRelation -cne 'fast-forward' -or $localVersion -cne '7.6.0' -or $remoteVersion -cne '7.6.1') { throw 'candidate-recovery-only-760-to-761-fast-forward' }
                        $recovery = Get-PbInstalledCandidateRecovery -ToolkitPath $toolkitRootFull -Commit $localCommit -TargetCommit $remoteCommit -Remote $Remote -ExtractionRoot $RecoveryExtractionRoot -ProjectRoot $projectRootFull
                        if ($recovery.status -ceq 'verified') { $recoveryCommand = "从副本 $($recovery.entrypoint) 运行 version 和 doctor；恢复或升级后重新生成当前 facts。" }
                        $nextActions += '副本仅用于 candidate-recovery-only / toolkit-only，不能发布或转移授权；从 recovery.entrypoint 运行 version/doctor，升级后重新生成当前 facts。'
                    }
                    elseif ($ReleaseRecordPath -and $RecoveryArtifactRoot -and $RecoveryExtractionRoot) {
                        $recovery = Get-PbReleaseRecoveryPreview -RecordPath $ReleaseRecordPath -PublicationReceiptPath $PublicationReceiptPath -ArtifactRoot $RecoveryArtifactRoot -ExtractionRoot $RecoveryExtractionRoot -Purpose $RecoveryPurpose
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
                        if (($Apply.IsPresent -or $RecoveryPurpose -ceq 'InstalledCandidateRecovery') -and $recovery.status -ne 'verified') {
                            $status='blocked'
                            $issues += New-ToolkitUpdateIssue -Code 'toolkit-recovery-unverified' -Severity error -Message $recovery.reasonCode
                            $nextActions += if ($RecoveryPurpose -ceq 'InstalledCandidateRecovery') { '核对清洁 7.6.0 候选与官方 7.6.1 快进目标，保留失败目录，显式选择新的树外 RecoveryExtractionRoot；不得混入发布材料。' } else { '提供旧发行树外记录、原始制品渠道与新的隔离恢复目录，核验旧完整身份及入口后再切换。' }
                        }
                        elseif (-not $Apply.IsPresent) {
                            $status = "outdated"
                            $issues += New-ToolkitUpdateIssue -Code "toolkit-snapshot-outdated" -Severity "warning" -Message "本地 Toolkit 快照落后远端 $Remote/$Branch。"
                            $nextActions += "运行 scripts/pbbridge-toolkit-update.ps1 -Apply 更新 Toolkit submodule 工作树。"
                        }
                        elseif ($PSCmdlet.ShouldProcess($toolkitRootFull, "Checkout Toolkit snapshot $remoteCommit")) {
                            if ($RecoveryPurpose -ceq 'InstalledCandidateRecovery') {
                                $recovery = Get-PbInstalledCandidateRecovery -ToolkitPath $toolkitRootFull -Commit $localCommit -TargetCommit $remoteCommit -Remote $Remote -ExtractionRoot $RecoveryExtractionRoot -ProjectRoot $projectRootFull -RequireExisting
                                if ($recovery.status -cne 'verified') { throw $recovery.reasonCode }
                                $rechecked=Get-PbToolkitSnapshotIdentity -ToolkitPath $toolkitRootFull -Commit $remoteCommit
                                foreach ($field in @('productVersion','cliSha256','toolkitCommit','runtimeContractSha256','manifestSha256')) {
                                    if ([string]$rechecked.identity.$field -cne [string]$targetBuild.identity.$field) { throw 'candidate-recovery-target-changed' }
                                }
                            }
                            $lfsPrefetch=Save-ToolkitTargetLfs -Root $toolkitRootFull -Commit $remoteCommit
                            $checkout = Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @("checkout", "--detach", $remoteCommit)
                            if ($checkout.exitCode -ne 0) {
                                $issues += New-ToolkitUpdateIssue -Code "toolkit-checkout-failed" -Severity "error" -Message "更新 Toolkit 快照失败：$($checkout.text)"
                                $nextActions += "手工进入 Toolkit submodule 检查 git checkout 失败原因。"
                            }
                            else {
                                Test-ToolkitInstalledContent -Root $toolkitRootFull -Commit $remoteCommit
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
                                    $lfsPrefetch=Save-ToolkitTargetLfs -Root $toolkitRootFull -Commit $remoteCommit
                                    $checkout = Invoke-ToolkitGit -WorkingDirectory $toolkitRootFull -Arguments @("checkout", "--detach", $remoteCommit)
                                    if ($checkout.exitCode -ne 0) {
                                        $issues += New-ToolkitUpdateIssue -Code "toolkit-checkout-failed" -Severity "error" -Message "历史断代切换失败：$($checkout.text)"
                                        $nextActions += "保持原分支不动，按 recoveryCommand 返回 previousCommit。"
                                    }
                                    else {
                                        Test-ToolkitInstalledContent -Root $toolkitRootFull -Commit $remoteCommit
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
