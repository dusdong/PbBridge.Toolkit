#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.5.3
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = "",
    [string]$WorkspaceName = "",
    [string]$BaselineOutputPath = "",
    [string]$CurrentOutputPath = "",
    [string[]]$ObjectKey,
    [string]$ObjectListPath = "",
    [ValidateSet('auto', 'utf-8', 'gbk', 'utf-8-bom', 'utf-16le')]
    [string]$SourceEncoding = 'auto',
    [ValidateSet('object', 'target-pbl', 'all')]
    [string]$VerifyScope = 'object',
    [ValidateRange(0, 32)]
    [int]$DiffParallelism = 0,
    [string]$ResultJsonPath = "",
    [string]$PreflightResultJsonPath = "",
    [switch]$AllowMultiPblPlan,
    [switch]$Apply,
    [switch]$WriteBack,
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-import-objects.ps1" -CliCommand "pbbridge import objects"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @("import", "objects", "--help"); exit 0 }



function Resolve-PbBridgeWorkspaceName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "必须显式提供 -WorkspaceName <id>；wrapper 会将其转发为 CLI --workspace <id>。"
    }

    $normalized = $Name.Trim().ToLowerInvariant()
    if ($normalized -notmatch '^[a-z0-9_-]+$') {
        throw "WorkspaceName 只能包含小写字母、数字、- 和 _：$Name"
    }

    return $normalized
}

function ConvertTo-SafeFileName {
    param([string]$Value)

    $safe = ($Value -replace '[^A-Za-z0-9_.-]', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return "objects"
    }

    return $safe
}

$RepoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot
$workspaceRootName = Resolve-PbBridgeWorkspaceName -Name $WorkspaceName
$pbbridgeWorkspaceRoot = Join-Path $RepoRoot (Join-Path ".pbbridge\workspaces" $workspaceRootName)
if ([string]::IsNullOrWhiteSpace($BaselineOutputPath)) {
    $BaselineOutputPath = Join-Path $pbbridgeWorkspaceRoot "baseline\pbbridge"
}
if ([string]::IsNullOrWhiteSpace($CurrentOutputPath)) {
    $CurrentOutputPath = Join-Path $pbbridgeWorkspaceRoot "artifacts\pbbridge"
}

$baselinePath = [System.IO.Path]::GetFullPath($BaselineOutputPath)
$currentPath = [System.IO.Path]::GetFullPath($CurrentOutputPath)
$objectKeys = [System.Collections.Generic.List[string]]::new()
foreach ($key in @($ObjectKey)) {
    if (-not [string]::IsNullOrWhiteSpace($key)) {
        $objectKeys.Add($key.Trim()) | Out-Null
    }
}
if (-not [string]::IsNullOrWhiteSpace($ObjectListPath)) {
    $objectListFullPath = [System.IO.Path]::GetFullPath($ObjectListPath)
    foreach ($line in [System.IO.File]::ReadLines($objectListFullPath, [System.Text.Encoding]::UTF8)) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -gt 0 -and -not $trimmed.StartsWith('#')) {
            $objectKeys.Add($trimmed) | Out-Null
        }
    }
}
if ($objectKeys.Count -eq 0) {
    throw "import-objects 至少需要一个 -ObjectKey 或 -ObjectListPath。"
}

if ([string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    $ResultJsonPath = Join-Path $RepoRoot (".pbbridge\local\results\import-objects\import-objects-{0}.json" -f (ConvertTo-SafeFileName -Value ($objectKeys -join '-')))
}
$resultPath = [System.IO.Path]::GetFullPath($ResultJsonPath)
$toolkitRoot = Join-Path $RepoRoot ".pbbridge\PbBridge.Toolkit"
$cliExe = Join-Path $toolkitRoot "runtime\cli\win-x86\PbBridge.Cli.exe"

if (-not (Test-Path -LiteralPath $cliExe -PathType Leaf)) {
    throw "未找到 CLI：$cliExe"
}
if (-not (Test-Path -LiteralPath $baselinePath -PathType Container)) {
    throw "未找到 baseline artifacts：$baselinePath。请先运行 full/readonly sync。"
}
if (-not (Test-Path -LiteralPath $currentPath -PathType Container)) {
    throw "未找到 current artifacts：$currentPath。请先运行 pbbridge-readonly-sync.ps1。"
}

$arguments = @(
    'import-objects',
    '--baseline', $baselinePath,
    '--current', $currentPath,
    '--workspace-path', $RepoRoot,
    '--result', $resultPath,
    '--source-encoding', $SourceEncoding,
    '--verify-scope', $VerifyScope
)
if (-not [string]::IsNullOrWhiteSpace($WorkspaceName)) {
    $arguments += @('--workspace', $WorkspaceName.Trim())
}
foreach ($key in @($objectKeys)) {
    $arguments += @('--object', $key)
}
if ($Apply.IsPresent) {
    $arguments += '--apply'
}
if ($WriteBack.IsPresent) {
    $arguments += '--writeback'
}
if ($DiffParallelism -gt 0) {
    $arguments += @('--diff-parallelism', ([string]$DiffParallelism))
}
if ($AllowMultiPblPlan.IsPresent) {
    $arguments += '--allow-multi-pbl-plan'
}
if (-not [string]::IsNullOrWhiteSpace($PreflightResultJsonPath)) {
    $arguments += @('--preflight-result', [System.IO.Path]::GetFullPath($PreflightResultJsonPath))
}

$commandResult = Invoke-PbBridgeNativeCommand -FilePath $cliExe -Arguments $arguments -WorkingDirectory $RepoRoot -CaptureStdout
Complete-PbBridgeNativeCommand -Result $commandResult
