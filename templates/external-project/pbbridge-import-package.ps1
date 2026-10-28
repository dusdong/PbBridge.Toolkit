#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.0
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = "",
    [string]$PlanJsonPath,
    [string]$PackageDir = "",
    [ValidateSet('Create', 'DryRun', 'Apply')]
    [string]$Mode = 'Create',
    [ValidateSet('object', 'target-pbl', 'all')]
    [string]$VerifyScope = 'object',
    [ValidateSet('auto', 'utf-8', 'gbk', 'utf-8-bom', 'utf-16le')]
    [string]$SourceEncoding = 'auto',
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-import-package.ps1" -CliCommand "pbbridge import-package"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @("import-package", "--help"); exit 0 }



$RepoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot
$toolkitRoot = Join-Path $RepoRoot ".pbbridge\PbBridge.Toolkit"
$cliExe = Join-Path $toolkitRoot "runtime\cli\win-x86\PbBridge.Cli.exe"
if (-not (Test-Path -LiteralPath $cliExe -PathType Leaf)) {
    throw "未找到 PbBridge CLI：$cliExe"
}

if ([string]::IsNullOrWhiteSpace($PlanJsonPath)) {
    throw "必须提供 -PlanJsonPath。"
}

if ([string]::IsNullOrWhiteSpace($PackageDir)) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $PackageDir = Join-Path $RepoRoot (Join-Path ".pbbridge\import-packages" $timestamp)
}

$planFullPath = [System.IO.Path]::GetFullPath($PlanJsonPath)
$packageFullPath = [System.IO.Path]::GetFullPath($PackageDir)
$packageJsonPath = Join-Path $packageFullPath "package.json"

if ($Mode -eq 'Create') {
    & $cliExe import-package create $planFullPath $packageFullPath --include-type menu,window,datawindow --verify-scope $VerifyScope --source-encoding $SourceEncoding
    if ($LASTEXITCODE -ne 0) {
        throw "import-package create 失败，退出码：$LASTEXITCODE"
    }
    Write-Host "Import package 已创建：$packageJsonPath"
    exit 0
}

if (-not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf)) {
    & $cliExe import-package create $planFullPath $packageFullPath --include-type menu,window,datawindow --verify-scope $VerifyScope --source-encoding $SourceEncoding
    if ($LASTEXITCODE -ne 0) {
        throw "import-package create 失败，退出码：$LASTEXITCODE"
    }
}

$resultJsonPath = Join-Path $packageFullPath ("import-package.{0}.json" -f $Mode.ToLowerInvariant())
$cliMode = if ($Mode -eq 'Apply') { 'apply' } else { 'dry-run' }
& $cliExe import-package run $packageJsonPath $resultJsonPath --mode $cliMode --source-encoding $SourceEncoding
if ($LASTEXITCODE -ne 0) {
    throw "import-package run 失败，退出码：$LASTEXITCODE"
}

Write-Host "Import package $Mode 完成：$resultJsonPath"
Write-Host "仍需在 PowerBuilder IDE 中执行 Regenerate / Full Build / 运行验收。"
