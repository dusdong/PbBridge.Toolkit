#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.0
param(
    [string]$ProjectRoot = "",
    [string]$SharedLibraryPath,
    [string]$SharedLibraryConfigPath,
    [string]$WorkspacePath,
    [ValidateSet("self", "consumer")]
    [string]$EvidenceMode,
    [string]$ParentOutputPath,
    [string]$SharedOutputPath,
    [string]$ResultJsonPath,
    [string]$SourceLayout,
    [string]$ScanScope,
    [string[]]$IncludeLibrary = @(),
    [string[]]$ExcludeLibrary = @(),
    [switch]$AllowVerifyIssues,
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-shared-library-evidence.ps1" -CliCommand ""; exit 0 }
if ($CliHelp.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-shared-library-evidence.ps1" -CliCommand ""; exit 0 }
Assert-PbBridgeRequiredParameter -Name "SharedLibraryPath" -Value $SharedLibraryPath
Assert-PbBridgeRequiredParameter -Name "SharedLibraryPath" -Value $SharedLibraryPath

function Resolve-FullPath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$PathValue
    )

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $PathValue))
}



function Write-JsonUtf8 {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    return [System.IO.File]::ReadAllText($resolvedPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

function Get-ObjectPropertyValue {
    param(
        [object]$InputObject,
        [string]$Name
    )

    if ($null -eq $InputObject -or $null -eq $InputObject.PSObject.Properties[$Name]) {
        return $null
    }

    return $InputObject.PSObject.Properties[$Name].Value
}

function Get-StringArrayProperty {
    param(
        [object]$InputObject,
        [string]$Name
    )

    $value = Get-ObjectPropertyValue -InputObject $InputObject -Name $Name
    if ($null -eq $value) {
        return @()
    }

    return @($value | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
}

function ConvertTo-NormalizedRelativePath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return ""
    }

    return ([string]$PathValue).Replace('\', '/').Trim('/')
}

function ConvertTo-RepoRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PathValue
    )

    $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $fullPath = [System.IO.Path]::GetFullPath($PathValue)
    if (-not $fullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }

    return $fullPath.Substring($root.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar).Replace('\', '/')
}

function Test-IsUnderRelativePath {
    param(
        [string]$PathValue,
        [string]$RelativeRoot
    )

    $normalizedPath = ConvertTo-NormalizedRelativePath -PathValue $PathValue
    $normalizedRoot = ConvertTo-NormalizedRelativePath -PathValue $RelativeRoot
    if ([string]::IsNullOrWhiteSpace($normalizedPath) -or [string]::IsNullOrWhiteSpace($normalizedRoot)) {
        return $false
    }

    return $normalizedPath.Equals($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $normalizedPath.StartsWith($normalizedRoot + '/', [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-ExcludePatternCoversSharedLibrary {
    param(
        [string]$Pattern,
        [string]$SharedRelativePath
    )

    $normalizedPattern = ConvertTo-NormalizedRelativePath -PathValue $Pattern
    $normalizedSharedPath = ConvertTo-NormalizedRelativePath -PathValue $SharedRelativePath
    if ([string]::IsNullOrWhiteSpace($normalizedPattern) -or [string]::IsNullOrWhiteSpace($normalizedSharedPath)) {
        return $false
    }

    return $normalizedPattern.Equals($normalizedSharedPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        $normalizedPattern.StartsWith($normalizedSharedPath + '/', [System.StringComparison]::OrdinalIgnoreCase) -or
        ($normalizedSharedPath -like $normalizedPattern) -or
        (($normalizedSharedPath + '/__pbbridge__') -like $normalizedPattern)
}

function Get-ConfiguredSharedLibraryEntry {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRootFull,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][string]$SharedLibraryFullPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        return $null
    }

    $config = Read-JsonFile -Path $ConfigPath
    if ($config.schemaName -ne "pbbridge-shared-library-config") {
        throw "共享库配置 schemaName 必须是 pbbridge-shared-library-config：$ConfigPath"
    }

    $sharedRelativePath = ConvertTo-NormalizedRelativePath -PathValue (ConvertTo-RepoRelativePath -RepoRoot $ProjectRootFull -PathValue $SharedLibraryFullPath)
    foreach ($entry in @($config.sharedLibraries)) {
        $entryPath = ConvertTo-NormalizedRelativePath -PathValue ([string]$entry.path)
        if ([string]::IsNullOrWhiteSpace($entryPath)) {
            continue
        }

        $entryFullPath = Resolve-FullPath -BasePath $ProjectRootFull -PathValue $entryPath
        if ($entryPath.Equals($sharedRelativePath, [System.StringComparison]::OrdinalIgnoreCase) -or
            $entryFullPath.Equals($SharedLibraryFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $entry
        }
    }

    return $null
}

function Invoke-Cli {
    param(
        [Parameter(Mandatory = $true)][string]$CliExe,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    $output = & $CliExe @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -and -not $AllowFailure.IsPresent) {
        throw "PbBridge.Cli $($Arguments -join ' ') failed with exit code ${exitCode}: $($output -join [Environment]::NewLine)"
    }

    return [pscustomobject]@{
        exitCode = $exitCode
        output = @($output)
    }
}

$ProjectRoot = Resolve-TemplateProjectRoot -ExplicitRoot $ProjectRoot
$projectRootFull = [System.IO.Path]::GetFullPath($ProjectRoot)
$sharedLibraryFullPath = Resolve-FullPath -BasePath $projectRootFull -PathValue $SharedLibraryPath
if (-not (Test-Path -LiteralPath $sharedLibraryFullPath -PathType Container)) {
    throw "共享库目录不存在：$sharedLibraryFullPath"
}

$resolvedConfigPath = if ([string]::IsNullOrWhiteSpace($SharedLibraryConfigPath)) {
    Join-Path $projectRootFull ".pbbridge\shared-libraries.json"
}
else {
    Resolve-FullPath -BasePath $projectRootFull -PathValue $SharedLibraryConfigPath
}
$configuredEntry = Get-ConfiguredSharedLibraryEntry -ProjectRootFull $projectRootFull -ConfigPath $resolvedConfigPath -SharedLibraryFullPath $sharedLibraryFullPath

$toolkitRoot = Join-Path $projectRootFull ".pbbridge\PbBridge.Toolkit"
$cliExe = Join-Path $toolkitRoot "runtime\cli\win-x86\PbBridge.Cli.exe"

$configuredParentOutputPath = [string](Get-ObjectPropertyValue -InputObject $configuredEntry -Name "parentOutputPath")
$parentOutputFullPath = if (-not [string]::IsNullOrWhiteSpace($ParentOutputPath)) {
    Resolve-FullPath -BasePath $projectRootFull -PathValue $ParentOutputPath
}
elseif (-not [string]::IsNullOrWhiteSpace($configuredParentOutputPath)) {
    Resolve-FullPath -BasePath $projectRootFull -PathValue $configuredParentOutputPath
}
else {
    Join-Path $projectRootFull ".pbbridge\workspaces\default\artifacts\pbbridge"
}

$configuredSharedOutputPath = [string](Get-ObjectPropertyValue -InputObject $configuredEntry -Name "sharedOutputPath")
$sharedOutputFullPath = if (-not [string]::IsNullOrWhiteSpace($SharedOutputPath)) {
    Resolve-FullPath -BasePath $projectRootFull -PathValue $SharedOutputPath
}
elseif (-not [string]::IsNullOrWhiteSpace($configuredSharedOutputPath)) {
    Resolve-FullPath -BasePath $projectRootFull -PathValue $configuredSharedOutputPath
}
else {
    Join-Path $sharedLibraryFullPath ".pbbridge\workspaces\default\artifacts\pbbridge"
}

$manifestPath = Join-Path $sharedOutputFullPath "manifest.json"
$configuredResultJsonPath = [string](Get-ObjectPropertyValue -InputObject $configuredEntry -Name "resultJsonPath")
$resultPath = if (-not [string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    Resolve-FullPath -BasePath $projectRootFull -PathValue $ResultJsonPath
}
elseif (-not [string]::IsNullOrWhiteSpace($configuredResultJsonPath)) {
    Resolve-FullPath -BasePath $projectRootFull -PathValue $configuredResultJsonPath
}
else {
    Join-Path $sharedOutputFullPath "shared-library-evidence.json"
}

$configuredWorkspacePath = [string](Get-ObjectPropertyValue -InputObject $configuredEntry -Name "workspacePath")
$configuredEvidenceMode = [string](Get-ObjectPropertyValue -InputObject $configuredEntry -Name "evidenceMode")
$configuredSourceLayout = [string](Get-ObjectPropertyValue -InputObject $configuredEntry -Name "sourceLayout")
$configuredScanScope = [string](Get-ObjectPropertyValue -InputObject $configuredEntry -Name "scanScope")
$effectiveEvidenceMode = if (-not [string]::IsNullOrWhiteSpace($EvidenceMode)) { $EvidenceMode } elseif (-not [string]::IsNullOrWhiteSpace($configuredEvidenceMode)) { $configuredEvidenceMode } else { "self" }
$effectiveEvidenceMode = $effectiveEvidenceMode.ToLowerInvariant()
if ($effectiveEvidenceMode -notin @("self", "consumer")) {
    throw "EvidenceMode 只能是 self 或 consumer。"
}
$effectiveWorkspacePath = if (-not [string]::IsNullOrWhiteSpace($WorkspacePath)) { $WorkspacePath } else { $configuredWorkspacePath }
$effectiveSourceLayout = if (-not [string]::IsNullOrWhiteSpace($SourceLayout)) { $SourceLayout } elseif (-not [string]::IsNullOrWhiteSpace($configuredSourceLayout)) { $configuredSourceLayout } else { "beside-pbl-src" }
$effectiveScanScope = if (-not [string]::IsNullOrWhiteSpace($ScanScope)) { $ScanScope } elseif (-not [string]::IsNullOrWhiteSpace($configuredScanScope)) { $configuredScanScope } else { "workspace-targets" }
$effectiveIncludeLibrary = if (@($IncludeLibrary).Count -gt 0) { @($IncludeLibrary) } else { Get-StringArrayProperty -InputObject $configuredEntry -Name "includeLibrary" }
$effectiveExcludeLibrary = if (@($ExcludeLibrary).Count -gt 0) { @($ExcludeLibrary) } else { Get-StringArrayProperty -InputObject $configuredEntry -Name "excludeLibrary" }

$sharedRelativePath = ConvertTo-RepoRelativePath -RepoRoot $projectRootFull -PathValue $sharedLibraryFullPath

if ($effectiveEvidenceMode -eq "consumer") {
    $parentManifestPath = Join-Path $parentOutputFullPath "manifest.json"
    $parentVerifyPath = Join-Path $parentOutputFullPath "verify.json"
    $parentReportPath = Join-Path $parentOutputFullPath "report.md"
    $parentDiagnosticsPath = Join-Path $parentOutputFullPath "diagnostics-bundle\index.json"
    $parentEvidence = @(
        [pscustomobject]@{ type = "parent-manifest"; path = $parentManifestPath; exists = (Test-Path -LiteralPath $parentManifestPath -PathType Leaf) },
        [pscustomobject]@{ type = "parent-verify"; path = $parentVerifyPath; exists = (Test-Path -LiteralPath $parentVerifyPath -PathType Leaf) },
        [pscustomobject]@{ type = "parent-report"; path = $parentReportPath; exists = (Test-Path -LiteralPath $parentReportPath -PathType Leaf) },
        [pscustomobject]@{ type = "parent-diagnostics-bundle"; path = $parentDiagnosticsPath; exists = (Test-Path -LiteralPath $parentDiagnosticsPath -PathType Leaf) }
    )
    $issues = @()
    foreach ($item in $parentEvidence) {
        if (-not $item.exists) {
            if ($item.type -eq "parent-diagnostics-bundle") {
                $issues += [pscustomobject]@{
                    code = "PARENT_DIAGNOSTICS_MISSING_READONLY_ONLY"
                    severity = "warning"
                    message = "consumer 模式缺少父项目 diagnostics-bundle；只读 smoke 不因此阻断，但正式发布仍建议生成诊断包证据。"
                    path = $item.path
                    nextAction = "如需完整诊断链，先运行会生成 diagnostics-bundle 的导入/复核流程，再重新执行 release-check。"
                }
            }
            else {
                $issues += [pscustomobject]@{
                    code = "PARENT_EVIDENCE_MISSING"
                    severity = "error"
                    message = "consumer 模式缺少父项目证据：$($item.type)"
                    path = $item.path
                    nextAction = "先运行父项目 scripts/pbbridge-readonly-sync.ps1，再运行 scripts/pbbridge-release-check.ps1 刷新父项目证据。"
                }
            }
        }
    }

    $matchedParentLibraries = @()
    if (Test-Path -LiteralPath $parentManifestPath -PathType Leaf) {
        $manifest = Read-JsonFile -Path $parentManifestPath
        $matchedParentLibraries = @($manifest.libraries | Where-Object {
            (Test-IsUnderRelativePath -PathValue ([string]$_.pblPath) -RelativeRoot $sharedRelativePath) -or
            (Test-IsUnderRelativePath -PathValue ([string]$_.sourceRoot) -RelativeRoot $sharedRelativePath)
        } | ForEach-Object {
            [pscustomobject]@{
                pblPath = [string]$_.pblPath
                sourceRoot = [string]$_.sourceRoot
            }
        })
    }
    if (@($matchedParentLibraries).Count -eq 0) {
        $matchedExcludePatterns = @($effectiveExcludeLibrary | Where-Object { Test-ExcludePatternCoversSharedLibrary -Pattern $_ -SharedRelativePath $sharedRelativePath })
        if ($matchedExcludePatterns.Count -gt 0) {
            $issues += [pscustomobject]@{
                code = "CONSUMER_EVIDENCE_EXCLUDED_BY_CONFIG"
                severity = "error"
                message = ("consumer 模式下，父项目 manifest 未命中共享库路径：{0}；当前 shared-libraries.json 的 excludeLibrary 可能排除了该共享库：{1}" -f $sharedRelativePath, ($matchedExcludePatterns -join ', '))
                path = $parentManifestPath
                nextAction = "调整该共享库配置的 excludeLibrary 并重新运行父项目 readonly sync，或改用 evidenceMode=self 并提供库级 verify/report/diagnostics 证据。"
            }
        }
        else {
            $issues += [pscustomobject]@{
                code = "PARENT_MANIFEST_SHARED_LIBRARY_NOT_COVERED"
                severity = "error"
                message = "consumer 模式下，父项目 manifest 未命中共享库路径：$sharedRelativePath"
                path = $parentManifestPath
                nextAction = "确认父项目 PBW/PBT 是否引用该共享库；引用后重新运行 scripts/pbbridge-readonly-sync.ps1。"
            }
        }
    }

    $blocked = @($issues | Where-Object severity -eq "error").Count -gt 0
    $result = [pscustomobject]@{
        schemaName = "pbbridge-shared-library-evidence"
        generatedAt = [DateTimeOffset]::Now.ToString("o")
        projectRoot = $projectRootFull
        configJsonPath = if (Test-Path -LiteralPath $resolvedConfigPath -PathType Leaf) { $resolvedConfigPath } else { $null }
        sharedLibraryPath = $sharedLibraryFullPath
        sharedLibraryRelativePath = $sharedRelativePath
        sharedOutputPath = $sharedOutputFullPath
        parentOutputPath = $parentOutputFullPath
        resultJsonPath = $resultPath
        evidenceMode = $effectiveEvidenceMode
        blocked = $blocked
        issues = @($issues)
        evidence = @($parentEvidence)
        parentEvidence = @($parentEvidence)
        matchedParentLibraries = @($matchedParentLibraries)
        limitations = @(
            "consumer 模式只证明父项目上下文已覆盖共享库路径，不能替代共享库仓库自身发布验收。"
            if (@($issues | Where-Object code -eq "PARENT_DIAGNOSTICS_MISSING_READONLY_ONLY").Count -gt 0) {
                "consumer 模式未发现父项目 diagnostics-bundle；当前仅使用 manifest/verify/report 证明父项目上下文覆盖共享库路径。"
            }
        )
        summaryText = if ($blocked) { "共享库 consumer 证据仍有缺失。" } else { "共享库 consumer 证据已生成。" }
    }

    Write-JsonUtf8 -Path $resultPath -Value $result
    $result | ConvertTo-Json -Depth 12
    if ($blocked) {
        exit 1
    }
    exit 0
}

$workspaceFullPath = $null
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    if ([string]::IsNullOrWhiteSpace($effectiveWorkspacePath)) {
        $nextAction = "运行 scripts/pbbridge-shared-library-evidence.ps1 -SharedLibraryPath $SharedLibraryPath -WorkspacePath <shared.pbw> 先生成共享库导出产物。"
        $result = [pscustomobject]@{
            schemaName = "pbbridge-shared-library-evidence"
            generatedAt = [DateTimeOffset]::Now.ToString("o")
            projectRoot = $projectRootFull
            configJsonPath = if (Test-Path -LiteralPath $resolvedConfigPath -PathType Leaf) { $resolvedConfigPath } else { $null }
            sharedLibraryPath = $sharedLibraryFullPath
            sharedLibraryRelativePath = $sharedRelativePath
            sharedOutputPath = $sharedOutputFullPath
            parentOutputPath = $parentOutputFullPath
            resultJsonPath = $resultPath
            evidenceMode = $effectiveEvidenceMode
            workspacePath = $null
            sourceLayout = $effectiveSourceLayout
            scanScope = $effectiveScanScope
            includeLibrary = @($effectiveIncludeLibrary)
            excludeLibrary = @($effectiveExcludeLibrary)
            blocked = $true
            issues = @(
                [pscustomobject]@{
                    code = "SHARED_LIBRARY_MANIFEST_MISSING"
                    severity = "error"
                    message = "共享库输出目录缺少 manifest.json。"
                    path = $manifestPath
                    nextAction = $nextAction
                }
            )
            evidence = @()
            parentEvidence = @()
            matchedParentLibraries = @()
            limitations = @()
            summaryText = "共享库缺少 PbBridge 导出产物；需要提供 -WorkspacePath 完成首次只读导出。"
        }

        Write-JsonUtf8 -Path $resultPath -Value $result
        $result | ConvertTo-Json -Depth 12
        exit 1
    }

    if (-not (Test-Path -LiteralPath $cliExe -PathType Leaf)) {
        throw "未找到 Toolkit CLI：$cliExe"
    }

    $workspaceFullPath = Resolve-FullPath -BasePath $sharedLibraryFullPath -PathValue $effectiveWorkspacePath
    $exportArguments = @("export", $workspaceFullPath, $sharedOutputFullPath, "--source-layout", $effectiveSourceLayout, "--scan-scope", $effectiveScanScope)
    foreach ($pattern in @($effectiveIncludeLibrary)) {
        $exportArguments += @("--include-library", $pattern)
    }
    foreach ($pattern in @($effectiveExcludeLibrary)) {
        $exportArguments += @("--exclude-library", $pattern)
    }

    Invoke-Cli -CliExe $cliExe -Arguments $exportArguments | Out-Null
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "共享库输出目录缺少 manifest.json；请先在共享库工作区生成 PbBridge 导出产物：$sharedOutputFullPath"
}

if (-not (Test-Path -LiteralPath $cliExe -PathType Leaf)) {
    throw "未找到 Toolkit CLI：$cliExe"
}

$verifyPath = Join-Path $sharedOutputFullPath "verify.json"
$reportPath = Join-Path $sharedOutputFullPath "report.md"
$diagnosticsIndexPath = Join-Path $sharedOutputFullPath "diagnostics-bundle\index.json"

$verifyRun = Invoke-Cli -CliExe $cliExe -Arguments @("verify", $sharedOutputFullPath) -AllowFailure:$AllowVerifyIssues
$reportRun = Invoke-Cli -CliExe $cliExe -Arguments @("report", $sharedOutputFullPath)

if (-not (Test-Path -LiteralPath $diagnosticsIndexPath -PathType Leaf)) {
    Write-JsonUtf8 -Path $diagnosticsIndexPath -Value ([pscustomobject]@{
        schemaName = "pbbridge-shared-library-diagnostics-placeholder"
        generatedAt = [DateTimeOffset]::Now.ToString("o")
        sharedLibraryPath = $sharedLibraryFullPath
        sharedOutputPath = $sharedOutputFullPath
        note = "No import diagnostics were generated; this index records readonly verify/report evidence for shared-library gate consumption."
        bundles = @()
    })
}

$evidence = @(
    [pscustomobject]@{ type = "shared-verify"; path = $verifyPath; exists = (Test-Path -LiteralPath $verifyPath -PathType Leaf) },
    [pscustomobject]@{ type = "shared-report"; path = $reportPath; exists = (Test-Path -LiteralPath $reportPath -PathType Leaf) },
    [pscustomobject]@{ type = "shared-diagnostics-bundle"; path = $diagnosticsIndexPath; exists = (Test-Path -LiteralPath $diagnosticsIndexPath -PathType Leaf) }
)

$blocked = @($evidence | Where-Object { -not $_.exists }).Count -gt 0
$result = [pscustomobject]@{
    schemaName = "pbbridge-shared-library-evidence"
    generatedAt = [DateTimeOffset]::Now.ToString("o")
    projectRoot = $projectRootFull
    configJsonPath = if (Test-Path -LiteralPath $resolvedConfigPath -PathType Leaf) { $resolvedConfigPath } else { $null }
    sharedLibraryPath = $sharedLibraryFullPath
    sharedLibraryRelativePath = $sharedRelativePath
    sharedOutputPath = $sharedOutputFullPath
    parentOutputPath = $parentOutputFullPath
    resultJsonPath = $resultPath
    evidenceMode = $effectiveEvidenceMode
    blocked = $blocked
    verifyExitCode = $verifyRun.exitCode
    reportExitCode = $reportRun.exitCode
    workspacePath = $workspaceFullPath
    sourceLayout = $effectiveSourceLayout
    scanScope = $effectiveScanScope
    includeLibrary = @($effectiveIncludeLibrary)
    excludeLibrary = @($effectiveExcludeLibrary)
    evidence = $evidence
    parentEvidence = @()
    matchedParentLibraries = @()
    limitations = @()
    summaryText = if ($blocked) { "共享库标准证据仍有缺失。" } else { "共享库标准证据已生成。" }
}

Write-JsonUtf8 -Path $resultPath -Value $result
$result | ConvertTo-Json -Depth 12

if ($blocked) {
    exit 1
}
