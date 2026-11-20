#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.7.1
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-source-accepted.ps1" -CliCommand ""; exit 0 }
if ($CliHelp.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-source-accepted.ps1" -CliCommand ""; exit 0 }

$importScript = Join-Path $PSScriptRoot "pbbridge-import-plan.ps1"
if (-not (Test-Path -LiteralPath $importScript -PathType Leaf)) {
    throw "未找到 pbbridge-import-plan.ps1：$importScript"
}

$planParameters = @{
    RepoRoot = $RepoRoot
    WorkspaceName = $WorkspaceName
    BaselineOutputPath = $BaselineOutputPath
    CurrentOutputPath = $CurrentOutputPath
    SourceEncoding = $SourceEncoding
    SourceOnlyAccepted = $true
}
if (-not [string]::IsNullOrWhiteSpace($PlanJsonPath)) { $planParameters.PlanJsonPath = $PlanJsonPath }
if (-not [string]::IsNullOrWhiteSpace($ObjectKey)) { $planParameters.ObjectKey = $ObjectKey }
if ($UseExistingPlan.IsPresent) { $planParameters.UseExistingPlan = $true }
if ($AllowDirtySubmodule.IsPresent) { $planParameters.AllowDirtySubmodule = $true }
if ($AllowPointerUpdate.IsPresent) { $planParameters.AllowPointerUpdate = $true }

& $importScript @planParameters
exit $LASTEXITCODE
