#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.0
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
    [string]$VerifyScope = 'object',
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-import-sr.ps1" -CliCommand "pbbridge import sr"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @("import", "sr", "--help"); exit 0 }



function Invoke-TemplateEntry {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptName,
        [string[]]$Arguments = @()
    )

    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "未找到模板入口：$scriptPath"
    }

    & $scriptPath @Arguments
    exit $LASTEXITCODE
}

$RepoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot

$commonArgs = @(
    '-RepoRoot', $RepoRoot,
    '-WorkspaceName', $WorkspaceName,
    '-BaselineOutputPath', $BaselineOutputPath,
    '-CurrentOutputPath', $CurrentOutputPath,
    '-SourceEncoding', $SourceEncoding
)
if ($AllowDirtySubmodule.IsPresent) { $commonArgs += '-AllowDirtySubmodule' }
if ($AllowPointerUpdate.IsPresent) { $commonArgs += '-AllowPointerUpdate' }

if ($SourceOnlyAccepted.IsPresent) {
    Write-Host "SourceOnlyAccepted 已启用，转入 pbbridge-source-accepted.ps1。"
    $sourceAcceptedArgs = @($commonArgs)
    if (-not [string]::IsNullOrWhiteSpace($PlanJsonPath)) { $sourceAcceptedArgs += @('-PlanJsonPath', $PlanJsonPath) }
    if (-not [string]::IsNullOrWhiteSpace($ObjectKey)) { $sourceAcceptedArgs += @('-ObjectKey', $ObjectKey) }
    if ($UseExistingPlan.IsPresent) { $sourceAcceptedArgs += '-UseExistingPlan' }
    Invoke-TemplateEntry -ScriptName 'pbbridge-source-accepted.ps1' -Arguments $sourceAcceptedArgs
}

if (-not [string]::IsNullOrWhiteSpace($ObjectKey) -and [string]::IsNullOrWhiteSpace($PlanJsonPath) -and -not $UseExistingPlan.IsPresent) {
    Write-Host "ObjectKey 已启用，转入 import-object 快路径。"
    Write-Host "未传 -Apply 时只生成 v4 DryRun，不会写回 .pbl；以 status、writebackVerdict、pblWritebackCount 和 sourceFactSet 判断真实写回状态。Apply/WriteBack 命中配置内共享库时会自动运行只读 shared-library gate；shared-library gate blocked 时必须停止。"
    Write-Host "旧 plan-object-import 链路仅保留给 SourceOnlyAccepted、PlanJsonPath、UseExistingPlan 等专家路径。"
    $objectArgs = @(
        '-RepoRoot', $RepoRoot,
        '-WorkspaceName', $WorkspaceName,
        '-BaselineOutputPath', $BaselineOutputPath,
        '-CurrentOutputPath', $CurrentOutputPath,
        '-ObjectKey', $ObjectKey,
        '-SourceEncoding', $SourceEncoding,
        '-VerifyScope', $VerifyScope
    )
    if ($Apply.IsPresent) {
        $objectArgs += @('-Apply', '-WriteBack')
    }
    Invoke-TemplateEntry -ScriptName 'pbbridge-import-object.ps1' -Arguments $objectArgs
}

Write-Host "转入 pbbridge-import-plan.ps1 专家导入链路。"
Write-Host "旧 plan-object-import 链路仅保留给 SourceOnlyAccepted、PlanJsonPath、UseExistingPlan 等专家路径。"
$planArgs = @($commonArgs)
if (-not [string]::IsNullOrWhiteSpace($PlanJsonPath)) { $planArgs += @('-PlanJsonPath', $PlanJsonPath) }
if (-not [string]::IsNullOrWhiteSpace($ObjectKey)) { $planArgs += @('-ObjectKey', $ObjectKey) }
$planArgs += @('-VerifyScope', $VerifyScope)
if ($Apply.IsPresent) { $planArgs += '-Apply' }
if ($UseExistingPlan.IsPresent) { $planArgs += '-UseExistingPlan' }
Invoke-TemplateEntry -ScriptName 'pbbridge-import-plan.ps1' -Arguments $planArgs
