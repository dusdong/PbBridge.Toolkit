#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.1
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = "",
    [string]$WorkspaceName = "",
    [string]$Source,
    [string]$TargetPbl,
    [string]$ObjectType,
    [string]$ObjectName,
    [ValidateSet('auto', 'utf-8', 'gbk', 'utf-8-bom', 'utf-16le')]
    [string]$SourceEncoding = 'auto',
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



$RepoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-import-source.ps1" -CliCommand "pbbridge import source"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @("import", "source", "--help"); exit 0 }
Assert-PbBridgeRequiredParameter -Name "Source" -Value $Source
Assert-PbBridgeRequiredParameter -Name "TargetPbl" -Value $TargetPbl
Assert-PbBridgeRequiredParameter -Name "ObjectType" -Value $ObjectType
Assert-PbBridgeRequiredParameter -Name "ObjectName" -Value $ObjectName
$sourcePath = [System.IO.Path]::GetFullPath($Source)
$targetPblPath = [System.IO.Path]::GetFullPath($TargetPbl)
if ([string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    $ResultJsonPath = Join-Path $RepoRoot (".pbbridge\local\results\import-source\import-source-{0}.json" -f ($ObjectName -replace '[^A-Za-z0-9_.-]', '_'))
}
$resultPath = [System.IO.Path]::GetFullPath($ResultJsonPath)
$toolkitRoot = Join-Path $RepoRoot ".pbbridge\PbBridge.Toolkit"
$cliExe = Join-Path $toolkitRoot "runtime\cli\win-x86\PbBridge.Cli.exe"

if (-not (Test-Path -LiteralPath $cliExe -PathType Leaf)) {
    throw "未找到 CLI：$cliExe"
}

$arguments = @(
    'import-source',
    '--source', $sourcePath,
    '--target-pbl', $targetPblPath,
    '--object-type', $ObjectType,
    '--object-name', $ObjectName,
    '--workspace-path', $RepoRoot,
    '--result', $resultPath,
    '--source-encoding', $SourceEncoding
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
