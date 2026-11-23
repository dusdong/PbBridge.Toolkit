#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.7.2
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
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$NoEnumerate)

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -NoEnumerate:$NoEnumerate
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

    if ([string]::IsNullOrWhiteSpace($PathValue) -or [string]::IsNullOrWhiteSpace($SharedLibraryPathValue)) {
        return $false
    }

    $normalizedPath = Resolve-SharedLibraryPlanPath -PathValue $PathValue
    $normalizedSharedPath = Resolve-SharedLibraryPlanPath -PathValue $SharedLibraryPathValue
    return $normalizedPath.Equals($normalizedSharedPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        $normalizedPath.StartsWith($normalizedSharedPath + '/', [System.StringComparison]::OrdinalIgnoreCase)
}

function Resolve-SharedLibraryPlanPath {
    param([string]$PathValue)

    return [System.IO.Path]::GetFullPath($PathValue.Replace('\', '/'), $RepoRoot).Replace('\', '/').TrimEnd('/')
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
    $repoPath = Resolve-SharedLibraryPlanPath -PathValue $RepoRoot
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
                    $sharedPath = Resolve-SharedLibraryPlanPath -PathValue ([string]$library.path)
                    if ($sharedPath.Equals($repoPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $hits.Add('.')
                    }
                    elseif ($sharedPath.StartsWith($repoPath + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
                        $hits.Add($sharedPath.Substring($repoPath.Length + 1))
                    }
                    else {
                        $hits.Add($sharedPath)
                    }
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

    $result = Invoke-PbBridgeNativeCommand -FilePath 'git' -Capture -StandardOutputEncoding ([Text.Encoding]::UTF8) -Arguments @(
        '-C', $RepoRoot, 'config', '--file', '.gitmodules', '--null', '--get-regexp', '^submodule\..*\.path$')
    if ($result.exitCode -ne 0) {
        return @()
    }

    foreach ($entry in $result.stdout.Split([char]0)) {
        # git config --null 以 LF 分隔键和值，以 NUL 结束记录。
        $separator = $entry.IndexOf([char]10)
        if ($separator -ge 0) {
            $entry.Substring($separator + 1).Replace('\', '/').Trim('/')
        }
    }
}

function Add-GitStatusPblPaths {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Paths,
        [string]$StatusText,
        [string]$PathPrefix = ""
    )

    $fields = $StatusText.Split([char]0)
    for ($index = 0; $index -lt $fields.Length; $index++) {
        $record = $fields[$index]
        if ($record.Length -lt 4) {
            continue
        }

        $candidates = @($record.Substring(3))
        if ($record.Substring(0, 2) -match '[RC]') {
            # -z 格式先给出目标，再给出原路径。
            $index++
            $candidates += $fields[$index]
        }
        foreach ($candidatePath in $candidates) {
            if ($candidatePath.EndsWith('.pbl', [System.StringComparison]::OrdinalIgnoreCase)) {
                $combinedPath = if (-not $PathPrefix) {
                    $candidatePath
                }
                else {
                    "$PathPrefix/$candidatePath"
                }
                $Paths.Add((ConvertTo-RepoRelativePblPath -PathValue $combinedPath))
            }
        }
    }
}

function Get-GitStatusText {
    param([string]$RepositoryPath)

    $result = Invoke-PbBridgeNativeCommand -FilePath 'git' -Capture -StandardOutputEncoding ([Text.Encoding]::UTF8) -Arguments @(
        '-C', $RepositoryPath, 'status', '--porcelain=v1', '-z', '--untracked-files=all')
    if ($result.exitCode -ne 0) {
        throw ("git status 执行失败。仓库：{0}；退出码：{1}。stderr：{2}" -f $RepositoryPath, $result.exitCode, $result.stderr)
    }
    return $result.stdout
}

function Get-GitPblStatusPaths {
    $paths = [System.Collections.Generic.List[string]]::new()
    Add-GitStatusPblPaths -Paths $paths -StatusText (Get-GitStatusText -RepositoryPath $RepoRoot)

    foreach ($submodulePath in @(Get-GitSubmodulePaths)) {
        $submoduleFullPath = Join-Path $RepoRoot $submodulePath
        # 取消初始化后目录可能仍存在，Git 会从中向上找到父仓库。
        if (-not (Test-Path -LiteralPath (Join-Path $submoduleFullPath '.git'))) {
            continue
        }

        Add-GitStatusPblPaths -Paths $paths -StatusText (Get-GitStatusText -RepositoryPath $submoduleFullPath) -PathPrefix $submodulePath
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

    $configMissing = -not (Test-Path -LiteralPath $sharedLibraryConfigPath -PathType Leaf)
    if ($configMissing) {
        if (-not $Apply.IsPresent) {
            return
        }

        Write-Host "SharedLibraryGate: 共享库配置缺失，正在执行只读 PB 共享库候选检查..."
    }
    else {
        $sharedLibraries = @(Get-SharedLibraryConfigEntries)
        if ($sharedLibraries.Count -eq 0) {
            return
        }

        if (-not (Test-ImportPlanHitsSharedLibrary -PlanPath $PlanPath -SharedLibraries $sharedLibraries)) {
            Write-Host "SharedLibraryGate: active plan 未命中共享库路径，跳过共享库回灌检查。"
            return
        }

        Write-Host "SharedLibraryGate: active plan 命中共享库路径，正在执行只读回灌门禁..."
    }

    # 检查脚本或 CLI 可能先于结果落盘失败。
    [System.IO.File]::Delete($sharedLibraryGateResultJsonPath)
    if (-not (Test-Path -LiteralPath $sharedLibraryCheckScript -PathType Leaf)) {
        throw "未找到共享库回灌检查脚本：$sharedLibraryCheckScript"
    }

    $gateParameters = @{
        ProjectRoot = $RepoRoot
        SharedLibraryConfigPath = $sharedLibraryConfigPath
        ParentOutputPath = $currentPath
        ResultJsonPath = $sharedLibraryGateResultJsonPath
    }
    if ($configMissing) {
        $gateParameters.WorkspaceName = $workspaceRootName
    }
    if ($AllowDirtySubmodule.IsPresent) {
        $gateParameters.AllowDirtySubmodule = $true
    }
    if ($AllowPointerUpdate.IsPresent) {
        $gateParameters.AllowPointerUpdate = $true
    }
    & $sharedLibraryCheckScript @gateParameters
    $gateExitCode = $LASTEXITCODE
    if ($gateExitCode -ne 0) {
        if (Test-Path -LiteralPath $sharedLibraryGateResultJsonPath -PathType Leaf) {
            throw "共享库回灌门禁阻断（退出码 $gateExitCode）。ResultJsonPath=$sharedLibraryGateResultJsonPath"
        }
        throw "共享库回灌检查失败（退出码 $gateExitCode），本次未生成报告。"
    }

    try {
        $gate = Read-JsonFile -Path $sharedLibraryGateResultJsonPath -NoEnumerate
    }
    catch {
        throw "无法读取本次共享库回灌门禁报告。ResultJsonPath=$sharedLibraryGateResultJsonPath。$($_.Exception.Message)"
    }
    if ($gate -isnot [System.Management.Automation.PSCustomObject]) {
        throw "共享库回灌门禁阻断。报告必须是 JSON 对象。ResultJsonPath=$sharedLibraryGateResultJsonPath"
    }
    $blockedProperty = $gate.PSObject.Properties['blocked']
    if ($null -eq $blockedProperty -or $blockedProperty.Value -isnot [bool]) {
        throw "共享库回灌门禁阻断。报告缺少有效的 blocked 布尔值。ResultJsonPath=$sharedLibraryGateResultJsonPath"
    }
    if ($gate.blocked) {
        throw "共享库回灌门禁阻断。ResultJsonPath=$sharedLibraryGateResultJsonPath"
    }
    $gateLibraryCount = @($gate.sharedLibraries).Count
    Write-Host ("SharedLibraryGate: {0}; blocked={1}; libraries={2}; result={3}" -f $gate.summaryText, $gate.blocked, $gateLibraryCount, $sharedLibraryGateResultJsonPath)
    if (-not $configMissing) {
        Write-Host "SharedLibraryGate: 配置内共享库门禁已通过；专家链路 Apply/WriteBack 可继续，无需额外共享库写回授权。"
    }
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
