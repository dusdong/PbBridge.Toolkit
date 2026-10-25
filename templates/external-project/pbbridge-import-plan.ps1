#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.5.3
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = "",
    [string]$WorkspaceName = "",
    [string]$BaselineOutputPath = "",
    [string]$CurrentOutputPath = "",
    [string]$PlanJsonPath,
    [string]$ObjectKey,
    [ValidateSet('auto', 'utf-8', 'gbk', 'utf-8-bom', 'utf-16le')]
    [string]$SourceEncoding = 'auto',
    [ValidateSet('object', 'target-pbl', 'all')]
    [string]$VerifyScope = 'all',
    [switch]$Apply,
    [switch]$SourceOnlyAccepted,
    [switch]$UseExistingPlan,
    [switch]$AllowDirtySubmodule,
    [switch]$AllowPointerUpdate,
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-import-plan.ps1" -CliCommand "pbbridge import plan"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @("import", "plan", "--help"); exit 0 }



function Resolve-PbBridgeWorkspaceName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "必须显式提供 -WorkspaceName <id>；本地 import artifacts 必须绑定明确 workspace。"
    }

    $normalized = $Name.Trim().ToLowerInvariant()
    if ($normalized -notmatch '^[a-z0-9_-]+$') {
        throw "WorkspaceName 只能包含小写字母、数字、- 和 _：$Name"
    }

    return $normalized
}

function Get-PbBridgeWorkspaceRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return Join-Path $Root (Join-Path ".pbbridge\workspaces" $Name)
}

$RepoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot
$workspaceRootName = Resolve-PbBridgeWorkspaceName -Name $WorkspaceName
$pbbridgeWorkspaceRoot = Get-PbBridgeWorkspaceRoot -Root $RepoRoot -Name $workspaceRootName
if ([string]::IsNullOrWhiteSpace($BaselineOutputPath)) {
    $BaselineOutputPath = Join-Path $pbbridgeWorkspaceRoot "baseline\pbbridge"
}
if ([string]::IsNullOrWhiteSpace($CurrentOutputPath)) {
    $CurrentOutputPath = Join-Path $pbbridgeWorkspaceRoot "artifacts\pbbridge"
}

$toolkitRoot = Join-Path $RepoRoot ".pbbridge\PbBridge.Toolkit"
$cliExe = Join-Path $toolkitRoot "runtime\cli\win-x86\PbBridge.Cli.exe"
$sharedLibraryConfigPath = Join-Path $RepoRoot ".pbbridge\shared-libraries.json"
$sharedLibraryCheckScript = Join-Path $RepoRoot "scripts\pbbridge-check-shared-library-writeback.ps1"
$sharedLibraryGateResultJsonPath = Join-Path $RepoRoot ".pbbridge\shared-library-writeback-check.import.json"
$baselinePath = [System.IO.Path]::GetFullPath($BaselineOutputPath)
$currentPath = [System.IO.Path]::GetFullPath($CurrentOutputPath)
$verifyJsonPath = Join-Path $currentPath "verify.json"
$diffJsonPath = Join-Path $currentPath "diff.json"
$requestedPlanJsonPath = $PlanJsonPath
$requestedObjectKey = $ObjectKey
$defaultPlanJsonPath = Join-Path $currentPath "plan-import.json"
$activePlanJsonPath = $defaultPlanJsonPath
$conflictJsonPath = Join-Path $currentPath "import-conflicts.json"
$dryRunJsonPath = Join-Path $currentPath "import-result.dryrun.json"
$applyJsonPath = Join-Path $currentPath "import-result.apply.json"
$useDirectedPlan = -not [string]::IsNullOrWhiteSpace($requestedPlanJsonPath)
$useObjectPlan = -not [string]::IsNullOrWhiteSpace($requestedObjectKey)
if (-not $PSBoundParameters.ContainsKey('VerifyScope')) {
    $VerifyScope = if ($useObjectPlan) { 'object' } else { 'all' }
}

function Resolve-InputPath {
    param([string]$PathValue)

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $PathValue))
}

if ($useDirectedPlan) {
    $activePlanJsonPath = Resolve-InputPath -PathValue $requestedPlanJsonPath
    $planBaseName = [System.IO.Path]::GetFileNameWithoutExtension($activePlanJsonPath)
    $planSuffix = if ($planBaseName.StartsWith("plan-import")) {
        $planBaseName.Substring("plan-import".Length)
    }
    else {
        "-" + $planBaseName
    }

    $conflictJsonPath = Join-Path $currentPath ("import-conflicts{0}.json" -f $planSuffix)
    $dryRunJsonPath = Join-Path $currentPath ("import-result{0}.dryrun.json" -f $planSuffix)
    $applyJsonPath = Join-Path $currentPath ("import-result{0}.apply.json" -f $planSuffix)
}

if (-not (Test-Path -LiteralPath $cliExe -PathType Leaf)) {
    throw "未找到 CLI：$cliExe"
}

if (-not $useDirectedPlan -and -not $UseExistingPlan.IsPresent -and -not (Test-Path -LiteralPath $baselinePath -PathType Container)) {
    throw "未找到基线导出目录：$baselinePath。请先保留一份未修改的导出基线。"
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

function ConvertTo-NormalizedRelativePath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return ""
    }

    $path = [string]$PathValue
    if ([System.IO.Path]::IsPathRooted($path)) {
        $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        $fullPath = [System.IO.Path]::GetFullPath($path)
        if ($fullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
            $path = $fullPath.Substring($root.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        }
    }

    return $path.Replace('\', '/').Trim('/')
}

function Test-IsUnderSharedLibraryPath {
    param(
        [string]$PathValue,
        [string]$SharedLibraryPathValue
    )

    $normalizedPath = ConvertTo-NormalizedRelativePath -PathValue $PathValue
    $normalizedSharedPath = ConvertTo-NormalizedRelativePath -PathValue $SharedLibraryPathValue
    if ([string]::IsNullOrWhiteSpace($normalizedPath) -or [string]::IsNullOrWhiteSpace($normalizedSharedPath)) {
        return $false
    }

    return $normalizedPath.Equals($normalizedSharedPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        $normalizedPath.StartsWith($normalizedSharedPath + '/', [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-SharedLibraryConfigEntries {
    if (-not (Test-Path -LiteralPath $sharedLibraryConfigPath -PathType Leaf)) {
        return @()
    }

    $config = Read-JsonFile -Path $sharedLibraryConfigPath
    if ($config.schemaName -ne "pbbridge-shared-library-config") {
        throw "共享库配置 schemaName 必须是 pbbridge-shared-library-config：$sharedLibraryConfigPath"
    }

    return @($config.sharedLibraries)
}

function Test-ImportPlanHitsSharedLibrary {
    param(
        [Parameter(Mandatory = $true)][string]$PlanPath,
        [Parameter(Mandatory = $true)]$SharedLibraries
    )

    if (-not (Test-Path -LiteralPath $PlanPath -PathType Leaf)) {
        return $false
    }

    $plan = Read-JsonFile -Path $PlanPath
    foreach ($step in @($plan.steps)) {
        $stepPaths = @(
            [string]$step.targetPblPath,
            [string]$step.sourceRoot,
            [string]$step.targetLibraryDirectory,
            [string]$step.sourceRelativePath
        )
        foreach ($library in @($SharedLibraries)) {
            foreach ($stepPath in $stepPaths) {
                if (Test-IsUnderSharedLibraryPath -PathValue $stepPath -SharedLibraryPathValue ([string]$library.path)) {
                    return $true
                }
            }
        }
    }

    return $false
}

function Get-ImportPlanSharedLibraryHits {
    param(
        [Parameter(Mandatory = $true)][string]$PlanPath,
        [Parameter(Mandatory = $true)]$SharedLibraries
    )

    if (-not (Test-Path -LiteralPath $PlanPath -PathType Leaf)) {
        return @()
    }

    $hits = [System.Collections.Generic.List[string]]::new()
    $plan = Read-JsonFile -Path $PlanPath
    foreach ($step in @($plan.steps)) {
        $stepPaths = @(
            [string]$step.targetPblPath,
            [string]$step.sourceRoot,
            [string]$step.targetLibraryDirectory,
            [string]$step.sourceRelativePath
        )
        foreach ($library in @($SharedLibraries)) {
            foreach ($stepPath in $stepPaths) {
                if (Test-IsUnderSharedLibraryPath -PathValue $stepPath -SharedLibraryPathValue ([string]$library.path)) {
                    $hits.Add((ConvertTo-NormalizedRelativePath -PathValue ([string]$library.path)))
                    break
                }
            }
        }
    }

    return @($hits | Sort-Object -Unique)
}

function ConvertTo-RepoRelativePblPath {
    param([string]$PathValue)

    $normalized = ConvertTo-NormalizedRelativePath -PathValue $PathValue
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return ""
    }

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        $fullPath = [System.IO.Path]::GetFullPath($PathValue)
        if ($fullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
            $normalized = $fullPath.Substring($root.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar).Replace('\', '/')
        }
        else {
            $normalized = $fullPath.Replace('\', '/')
        }
    }

    return $normalized.Trim('/')
}

function Get-ImportPlanTargetPblPaths {
    param([Parameter(Mandatory = $true)][string]$PlanPath)

    if (-not (Test-Path -LiteralPath $PlanPath -PathType Leaf)) {
        return @()
    }

    $paths = [System.Collections.Generic.List[string]]::new()
    $plan = Read-JsonFile -Path $PlanPath
    foreach ($step in @($plan.steps)) {
        foreach ($candidate in @([string]$step.targetPblPath, [string]$step.targetLibrary)) {
            if ([string]::IsNullOrWhiteSpace($candidate)) {
                continue
            }

            if (-not $candidate.EndsWith('.pbl', [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            $paths.Add((ConvertTo-RepoRelativePblPath -PathValue $candidate))
        }
    }

    return @($paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}

function Get-ImportPlanStepCount {
    param([Parameter(Mandatory = $true)][string]$PlanPath)

    if (-not (Test-Path -LiteralPath $PlanPath -PathType Leaf)) {
        return 0
    }

    $plan = Read-JsonFile -Path $PlanPath
    return @($plan.steps).Count
}

function Assert-ImportPlanTargetPblPaths {
    param(
        [Parameter(Mandatory = $true)][string]$PlanPath,
        [AllowEmptyCollection()][string[]]$PlanTargetPblPaths = @()
    )

    $stepCount = Get-ImportPlanStepCount -PlanPath $PlanPath
    if ($stepCount -gt 0 -and $PlanTargetPblPaths.Count -eq 0) {
        throw ("active plan 包含 {0} 个步骤，但无法解析目标 .pbl。activePlanJsonPath={1}。请确认 plan steps[] 包含 targetPblPath 或 targetLibrary 字段。" -f $stepCount, $PlanPath)
    }
}

function Get-GitSubmodulePaths {
    $gitmodulesPath = Join-Path $RepoRoot '.gitmodules'
    if (-not (Test-Path -LiteralPath $gitmodulesPath -PathType Leaf)) {
        return @()
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -C $RepoRoot config --file .gitmodules --get-regexp 'submodule\..*\.path' 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        return @()
    }

    return @($output | ForEach-Object {
        $parts = ([string]$_).Split(' ', 2, [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($parts.Count -eq 2) { $parts[1].Replace('\', '/').Trim('/') }
    })
}

function Add-GitStatusPblPaths {
    param(
        [Parameter(Mandatory = $true)][object]$Paths,
        [AllowEmptyCollection()][object[]]$StatusLines = @(),
        [string]$PathPrefix = ""
    )

    $pathList = $Paths -as [System.Collections.Generic.List[string]]
    if ($null -eq $pathList) {
        throw "Add-GitStatusPblPaths 需要 List[string] 类型的 Paths 参数。"
    }

    foreach ($line in @($StatusLines)) {
        $text = [string]$line
        if ($text.Length -lt 4) {
            continue
        }

        $pathText = $text.Substring(3).Trim()
        foreach ($candidate in @($pathText -split '\s+->\s+')) {
            $candidatePath = $candidate.Trim('"')
            if ($candidatePath.EndsWith('.pbl', [System.StringComparison]::OrdinalIgnoreCase)) {
                $combinedPath = if ([string]::IsNullOrWhiteSpace($PathPrefix)) {
                    $candidatePath
                }
                else {
                    ($PathPrefix.Trim('/') + '/' + $candidatePath.Trim('/'))
                }
                $pathList.Add((ConvertTo-RepoRelativePblPath -PathValue $combinedPath))
            }
        }
    }
}

function Get-GitPblStatusPaths {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -C $RepoRoot status --porcelain=v1 --untracked-files=all 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw "git status --porcelain 执行失败：$($output -join [Environment]::NewLine)"
    }

    $paths = [System.Collections.Generic.List[string]]::new()
    Add-GitStatusPblPaths -Paths $paths -StatusLines @($output)

    foreach ($submodulePath in @(Get-GitSubmodulePaths)) {
        $submoduleFullPath = Join-Path $RepoRoot $submodulePath
        if (-not (Test-Path -LiteralPath $submoduleFullPath -PathType Container)) {
            continue
        }

        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $submoduleOutput = & git -C $submoduleFullPath status --porcelain=v1 --untracked-files=all 2>&1
            $submoduleExitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        if ($submoduleExitCode -ne 0) {
            throw "git status --porcelain 执行失败：$($submoduleOutput -join [Environment]::NewLine)"
        }

        Add-GitStatusPblPaths -Paths $paths -StatusLines @($submoduleOutput) -PathPrefix $submodulePath
    }

    return @($paths | Sort-Object -Unique)
}

function Get-UnexpectedPblStatusPaths {
    param(
        [AllowEmptyCollection()][string[]]$StatusPaths = @(),
        [AllowEmptyCollection()][string[]]$PlanTargetPblPaths = @()
    )

    $allowed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in @($PlanTargetPblPaths)) {
        $null = $allowed.Add((ConvertTo-RepoRelativePblPath -PathValue $path))
    }

    return @($StatusPaths | Where-Object { -not $allowed.Contains((ConvertTo-RepoRelativePblPath -PathValue $_)) } | Sort-Object -Unique)
}

function Assert-NoUnexpectedPblStatus {
    param(
        [Parameter(Mandatory = $true)][string]$Stage,
        [AllowEmptyCollection()][string[]]$PlanTargetPblPaths = @()
    )

    $statusPaths = @(Get-GitPblStatusPaths)
    $unexpected = @(Get-UnexpectedPblStatusPaths -StatusPaths $statusPaths -PlanTargetPblPaths $PlanTargetPblPaths)
    if ($unexpected.Count -gt 0) {
        throw ("{0} 检测到计划外 .pbl 变更：{1}。请先恢复或人工确认这些 PBL 后重试。" -f $Stage, ($unexpected -join ', '))
    }

    Write-Host ("PBL drift guard: {0}; changedPblCount={1}; planTargetPblCount={2}" -f $Stage, $statusPaths.Count, $PlanTargetPblPaths.Count)
}

function Invoke-SharedLibraryGate {
    param([Parameter(Mandatory = $true)][string]$PlanPath)

    $sharedLibraries = @(Get-SharedLibraryConfigEntries)
    if ($sharedLibraries.Count -eq 0) {
        return
    }

    if (-not (Test-ImportPlanHitsSharedLibrary -PlanPath $PlanPath -SharedLibraries $sharedLibraries)) {
        Write-Host "SharedLibraryGate: active plan 未命中共享库路径，跳过共享库回灌检查。"
        return
    }

    if (-not (Test-Path -LiteralPath $sharedLibraryCheckScript -PathType Leaf)) {
        throw "active plan 命中共享库路径，但未找到共享库回灌检查脚本：$sharedLibraryCheckScript"
    }

    Write-Host "SharedLibraryGate: active plan 命中共享库路径，正在执行只读回灌门禁..."
    $gateArgs = @(
        '-ProjectRoot', $RepoRoot,
        '-SharedLibraryConfigPath', $sharedLibraryConfigPath,
        '-ParentOutputPath', $currentPath,
        '-ResultJsonPath', $sharedLibraryGateResultJsonPath
    )
    if ($AllowDirtySubmodule.IsPresent) {
        $gateArgs += '-AllowDirtySubmodule'
    }
    if ($AllowPointerUpdate.IsPresent) {
        $gateArgs += '-AllowPointerUpdate'
    }
    & $sharedLibraryCheckScript @gateArgs
    if ($LASTEXITCODE -ne 0) {
        throw "共享库回灌门禁阻断。ResultJsonPath=$sharedLibraryGateResultJsonPath"
    }

    $gate = Read-JsonFile -Path $sharedLibraryGateResultJsonPath
    $gateLibraryCount = @($gate.sharedLibraries).Count
    Write-Host ("SharedLibraryGate: {0}; blocked={1}; libraries={2}; result={3}" -f $gate.summaryText, $gate.blocked, $gateLibraryCount, $sharedLibraryGateResultJsonPath)
    Write-Host "SharedLibraryGate: 配置内共享库门禁已通过；专家链路 Apply/WriteBack 可继续，无需额外共享库写回授权。"
}

if (-not (Test-Path -LiteralPath $currentPath -PathType Container)) {
    throw "未找到当前导出目录：$currentPath。请先运行 pbbridge-readonly-sync.ps1 并让 Codex 修改 .sr*。"
}

if ($useDirectedPlan -and $useObjectPlan) {
    throw "PlanJsonPath 与 ObjectKey 只能选择一种定向方式。"
}

if ($UseExistingPlan.IsPresent -and $useObjectPlan) {
    throw "UseExistingPlan 不能与 ObjectKey 同时使用；请先生成对象级计划，或改用 PlanJsonPath 指向已有计划。"
}

if (($useDirectedPlan -or $UseExistingPlan.IsPresent) -and -not (Test-Path -LiteralPath $activePlanJsonPath -PathType Leaf)) {
    throw "未找到 active import plan：$activePlanJsonPath"
}

Write-Host "PbBridge import context:"
Write-Host "  RepoRoot: $RepoRoot"
Write-Host "  WorkspaceName: $workspaceRootName"
Write-Host "  BaselineOutputPath: $baselinePath"
Write-Host "  CurrentOutputPath: $currentPath"
Write-Host "  PlanJsonPath: $requestedPlanJsonPath"
Write-Host "  ObjectKey: $requestedObjectKey"
Write-Host ("  UseExistingPlan: {0}" -f $UseExistingPlan.IsPresent)
Write-Host ("  AllowDirtySubmodule: {0}" -f $AllowDirtySubmodule.IsPresent)
Write-Host ("  AllowPointerUpdate: {0}" -f $AllowPointerUpdate.IsPresent)
if ($useDirectedPlan -or $UseExistingPlan.IsPresent) {
    Write-Host "复用导入计划: $activePlanJsonPath"
}
if ($useObjectPlan) {
    Write-Host "定向对象: $requestedObjectKey"
}

if ($SourceOnlyAccepted.IsPresent) {
    $sourceAcceptedChecklistPath = Join-Path $currentPath "source-accepted-checklist.json"
    $sourceAcceptedSummary = [ordered]@{
        schemaName = "pbbridge-source-only-accepted"
        schemaVersion = 1
        generatedAt = [DateTimeOffset]::Now.ToString("o")
        activePlanJsonPath = $activePlanJsonPath
        sourceEncoding = $SourceEncoding
        verifyScope = $VerifyScope
        pblSynchronization = 'deferred-to-powerbuilder-ide'
        nextActions = @(
            "保留已接受的 .sr* 修改。",
            "由 PowerBuilder IDE 或受控专家链路完成后续 .pbl 同步。"
        )
    }
    $sourceAcceptedJson = $sourceAcceptedSummary | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($sourceAcceptedChecklistPath, $sourceAcceptedJson + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
    Write-Host "SourceOnlyAccepted 已启用，已写出 source-accepted-checklist.json；PBL 同步 deferred-to-powerbuilder-ide。"
    exit 0
}

Write-Host "正在执行 verify..."
& $cliExe verify $currentPath
if ($LASTEXITCODE -ne 0) {
    throw "verify 失败，退出码：$LASTEXITCODE"
}

if ($UseExistingPlan.IsPresent) {
    Write-Host "已启用 UseExistingPlan，跳过 diff 与 plan 生成，复用 active plan。"
}
elseif ($useDirectedPlan) {
    Write-Host "已提供定向 PlanJsonPath，跳过全量 diff 与 plan-import。"
}
elseif ($useObjectPlan) {
    $safeObjectName = ($requestedObjectKey -replace '[^A-Za-z0-9_.-]', '_')
    $activePlanJsonPath = Join-Path $currentPath ("plan-import-{0}.json" -f $safeObjectName)
    $conflictJsonPath = Join-Path $currentPath ("import-conflicts-{0}.json" -f $safeObjectName)
    $dryRunJsonPath = Join-Path $currentPath ("import-result-{0}.dryrun.json" -f $safeObjectName)
    $applyJsonPath = Join-Path $currentPath ("import-result-{0}.apply.json" -f $safeObjectName)
    Write-Host "正在生成对象级 plan-import..."
    & $cliExe plan-object-import $baselinePath $currentPath $activePlanJsonPath --object $requestedObjectKey --verify $verifyJsonPath --verify-scope $VerifyScope
    if ($LASTEXITCODE -ne 0) {
        throw "plan-object-import 失败，退出码：$LASTEXITCODE"
    }
}
else {
    Write-Host "正在执行全量 diff..."
    & $cliExe diff $baselinePath $currentPath
    if ($LASTEXITCODE -ne 0) {
        throw "diff 失败，退出码：$LASTEXITCODE"
    }

    Write-Host "正在生成全量 plan-import..."
    & $cliExe plan-import $diffJsonPath $activePlanJsonPath $verifyJsonPath --verify-scope $VerifyScope
    if ($LASTEXITCODE -ne 0) {
        throw "plan-import 失败，退出码：$LASTEXITCODE"
    }
}

$sharedLibraryHits = @(Get-ImportPlanSharedLibraryHits -PlanPath $activePlanJsonPath -SharedLibraries @(Get-SharedLibraryConfigEntries))
$planTargetPblPaths = @(Get-ImportPlanTargetPblPaths -PlanPath $activePlanJsonPath)
Assert-ImportPlanTargetPblPaths -PlanPath $activePlanJsonPath -PlanTargetPblPaths $planTargetPblPaths
Write-Host "Active import plan:"
Write-Host "  activePlanJsonPath: $activePlanJsonPath"
Write-Host ("  sharedLibraryHits: {0}" -f ($(if ($sharedLibraryHits.Count -gt 0) { $sharedLibraryHits -join ', ' } else { '<none>' })))
Write-Host ("  targetPblPaths: {0}" -f ($(if ($planTargetPblPaths.Count -gt 0) { $planTargetPblPaths -join ', ' } else { '<none>' })))

Invoke-SharedLibraryGate -PlanPath $activePlanJsonPath

Write-Host "正在执行冲突检查..."
& $cliExe resolve-import-conflicts $activePlanJsonPath $conflictJsonPath block
if ($LASTEXITCODE -ne 0) {
    throw "resolve-import-conflicts 失败，退出码：$LASTEXITCODE"
}

Write-Host "正在执行 import DryRun..."
& $cliExe --adapter pbspy import $activePlanJsonPath $dryRunJsonPath DryRun block --writeback --source-encoding $SourceEncoding --verify-scope $VerifyScope
if ($LASTEXITCODE -ne 0) {
    throw "import DryRun 失败，退出码：$LASTEXITCODE"
}

if (-not $Apply) {
    Write-Host "DryRun 已完成，未写回 .pbl。确认无误后再追加 -Apply。"
    exit 0
}

Assert-NoUnexpectedPblStatus -Stage 'Apply 前' -PlanTargetPblPaths $planTargetPblPaths

Write-Host "正在执行 import Apply，并写回 .pbl..."
& $cliExe --adapter pbspy import $activePlanJsonPath $applyJsonPath Apply block --writeback --post-apply-review --source-encoding $SourceEncoding --verify-scope $VerifyScope
if ($LASTEXITCODE -ne 0) {
    throw "import Apply 失败，退出码：$LASTEXITCODE"
}

Assert-NoUnexpectedPblStatus -Stage 'Apply 后' -PlanTargetPblPaths $planTargetPblPaths

$applyResult = Read-JsonFile -Path $applyJsonPath
if ($null -ne $applyResult.pipeline) {
    Write-Host ("Import pipeline 当前阶段: {0}; 失败阶段: {1}" -f $applyResult.pipeline.currentStage, $applyResult.pipeline.failedStage)
    if (-not [string]::IsNullOrWhiteSpace($applyResult.pipeline.recoveryAdvice)) {
        Write-Host ("Import pipeline 恢复建议: {0}" -f $applyResult.pipeline.recoveryAdvice)
    }
}
if (-not [string]::IsNullOrWhiteSpace($applyResult.diagnosticsBundleJsonPath)) {
    Write-Host ("诊断包索引: {0}" -f $applyResult.diagnosticsBundleJsonPath)
}
if ($applyResult.partialWriteback -eq $true) {
    throw "import Apply 出现部分写回并已尝试自动恢复。rollbackResultJsonPath=$($applyResult.rollbackResultJsonPath); recoveryErrorMessage=$($applyResult.recoveryErrorMessage)"
}

if ([int]$applyResult.pblWritebackFailedCount -gt 0) {
    throw "import Apply 出现 PBL 写回失败：$($applyResult.pblWritebackFailedCount)"
}

if ($applyResult.postApplyReviewStatus -eq "failed") {
    throw "import Apply 后反导出复核失败：$($applyResult.postApplyReviewMessage)"
}

if ([int]$applyResult.pblWritebackCount -le 0) {
    throw "import Apply 未写回任何 .pbl。请确认 toolkit runtime/pbspy/win-x86 可加载 PBSpy.dll 与 PBSDK，或配置 PBSPY_HOME/PB_HOME，并检查 CLI import 结果。"
}

Write-Host "导入完成。请在 PowerBuilder IDE 中执行编译、调试和运行验收。"
