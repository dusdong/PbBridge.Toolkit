#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.1
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = "",
    [string]$WorkspaceName = "",
    [string]$BaselineOutputPath = "",
    [string]$CurrentOutputPath = "",
    [string]$ObjectKey,
    [ValidateSet('auto', 'utf-8', 'gbk', 'utf-8-bom', 'utf-16le')]
    [string]$SourceEncoding = 'auto',
    [ValidateSet('object', 'target-pbl', 'all')]
    [string]$VerifyScope = 'object',
    [string]$ResultJsonPath = "",
    [string]$PreflightResultJsonPath = "",
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-import-object.ps1" -CliCommand "pbbridge import object"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @("import", "object", "--help"); exit 0 }
Assert-PbBridgeRequiredParameter -Name "ObjectKey" -Value $ObjectKey



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

function Get-PbBridgeWorkspaceRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return Join-Path $Root (Join-Path ".pbbridge\workspaces" $Name)
}

function ConvertTo-SafeFileName {
    param([string]$Value)

    $safe = ($Value -replace '[^A-Za-z0-9_.-]', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return "object"
    }

    return $safe
}

$RepoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot
Assert-PbBridgeRequiredParameter -Name "ObjectKey" -Value $ObjectKey
$workspaceRootName = Resolve-PbBridgeWorkspaceName -Name $WorkspaceName
$pbbridgeWorkspaceRoot = Get-PbBridgeWorkspaceRoot -Root $RepoRoot -Name $workspaceRootName
if ([string]::IsNullOrWhiteSpace($BaselineOutputPath)) {
    $BaselineOutputPath = Join-Path $pbbridgeWorkspaceRoot "baseline\pbbridge"
}
if ([string]::IsNullOrWhiteSpace($CurrentOutputPath)) {
    $CurrentOutputPath = Join-Path $pbbridgeWorkspaceRoot "artifacts\pbbridge"
}

$baselinePath = [System.IO.Path]::GetFullPath($BaselineOutputPath)
$currentPath = [System.IO.Path]::GetFullPath($CurrentOutputPath)
if ([string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    $ResultJsonPath = Join-Path $RepoRoot (".pbbridge\local\results\import-object\import-object-{0}.json" -f (ConvertTo-SafeFileName -Value $ObjectKey))
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
    'import-object', $ObjectKey,
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
if ($Apply.IsPresent) {
    $arguments += '--apply'
}
if ($WriteBack.IsPresent) {
    $arguments += '--writeback'
}
if (-not [string]::IsNullOrWhiteSpace($PreflightResultJsonPath)) {
    $arguments += @('--preflight-result', [System.IO.Path]::GetFullPath($PreflightResultJsonPath))
}

$commandResult = Invoke-PbBridgeNativeCommand -FilePath $cliExe -Arguments $arguments -WorkingDirectory $RepoRoot -CaptureStdout
Complete-PbBridgeNativeCommand -Result $commandResult
