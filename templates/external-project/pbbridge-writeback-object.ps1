#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.1
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = "",
    [Parameter(Position = 0)][string]$ObjectKey,
    [string]$Source,
    [string]$TargetPbl = "",
    [string]$WorkspaceName = "",
    [ValidateSet('auto', 'utf-8', 'gbk', 'utf-8-bom', 'utf-16le')]
    [string]$SourceEncoding = 'auto',
    [ValidateSet('strict', 'object-source-and-target-pbl')]
    [string]$DriftPolicy = 'strict',
    [string]$ResultJsonPath = "",
    [string]$PreflightResultJsonPath = "",
    [switch]$Apply,
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-writeback-object.ps1" -CliCommand "pbbridge writeback object"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @("writeback", "object", "--help"); exit 0 }
Assert-PbBridgeRequiredParameter -Name "Source" -Value $Source



$RepoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot
Assert-PbBridgeRequiredParameter -Name "ObjectKey" -Value $ObjectKey
Assert-PbBridgeRequiredParameter -Name "Source" -Value $Source
$sourcePath = [System.IO.Path]::GetFullPath($Source)
if ([string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    $ResultJsonPath = Join-Path $RepoRoot (".pbbridge\local\results\writeback-object\writeback-object-{0}.json" -f ($ObjectKey -replace '[^A-Za-z0-9_.-]', '_'))
}
$resultPath = [System.IO.Path]::GetFullPath($ResultJsonPath)
$toolkitRoot = Join-Path $RepoRoot ".pbbridge\PbBridge.Toolkit"
$cliExe = Join-Path $toolkitRoot "runtime\cli\win-x86\PbBridge.Cli.exe"

if (-not (Test-Path -LiteralPath $cliExe -PathType Leaf)) {
    throw "未找到 CLI：$cliExe"
}

$arguments = @(
    'writeback',
    'object',
    $ObjectKey,
    '--source', $sourcePath,
    '--workspace-path', $RepoRoot,
    '--result', $resultPath,
    '--source-encoding', $SourceEncoding,
    '--drift-policy', $DriftPolicy
)
if (-not [string]::IsNullOrWhiteSpace($WorkspaceName)) {
    $arguments += @('--workspace', $WorkspaceName.Trim())
}
if (-not [string]::IsNullOrWhiteSpace($TargetPbl)) {
    $arguments += @('--target-pbl', [System.IO.Path]::GetFullPath($TargetPbl))
}
if ($Apply.IsPresent) {
    $arguments += '--apply'
}
if (-not [string]::IsNullOrWhiteSpace($PreflightResultJsonPath)) {
    $arguments += @('--preflight-result', [System.IO.Path]::GetFullPath($PreflightResultJsonPath))
}

$commandResult = Invoke-PbBridgeNativeCommand -FilePath $cliExe -Arguments $arguments -WorkingDirectory $RepoRoot -CaptureStdout
Complete-PbBridgeNativeCommand -Result $commandResult
