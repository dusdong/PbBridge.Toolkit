#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.1
<#
.SYNOPSIS
从 V8 preflight 继续执行受控 PBL Apply。

.DESCRIPTION
该 wrapper 只负责 ShouldProcess、标准参数和 CLI 流式调用。workspace、对象、源码、facts freshness、冲突守卫和 policy 均由 V8 preflight 与 CLI/application 验证。
读取 operationAssessments 与 nextAction；partial 保留成功对象，先核对当前源码与目标，再对剩余范围重新 preflight。
performance.executionTiming 是本次 Apply 实测；缺失为 unavailable，不能用 preflight 数字补齐。

.EXAMPLE
.\scripts\pbbridge-delivery-continue.ps1 -RepoRoot . -From '.pbbridge/workspaces/canyin/results/delivery-v8/preflight.json' -Apply -Confirm:$false

.EXAMPLE
.\scripts\pbbridge-delivery-continue.ps1 -RepoRoot . -From '.pbbridge/workspaces/canyin/results/delivery-v8/preflight.json' -Apply -WhatIf

.NOTES
ShouldProcess 被拒绝或 WhatIf 时不会启动真实 Apply。
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = '',

    [Alias('PreflightResultJsonPath')]
    [string]$From = '',

    [string]$ResultJsonPath = '',
    [string]$PolicyPath = '',
    [string]$TokenEnvironmentVariable = '',
    [string]$TokenFile = '',

    [ValidateSet('auto', 'none', 'text', 'jsonl')]
    [string]$Progress = 'auto',

    [switch]$Apply,
    [switch]$ApplyIfEligible,
    [switch]$Help,
    [switch]$CliHelp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$wrapperModulePath = Join-Path $PSScriptRoot 'PbBridge.Wrapper.psm1'
if (-not (Test-Path -LiteralPath $wrapperModulePath -PathType Leaf)) {
    throw "未找到共享 wrapper module：$wrapperModulePath"
}
Import-Module $wrapperModulePath -Force -ErrorAction Stop

if ($Help.IsPresent) {
    Show-PbBridgeWrapperHelp -WrapperName 'pbbridge-delivery-continue.ps1' -CliCommand 'pbbridge delivery continue'
    return
}
if ($CliHelp.IsPresent) {
    Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @('delivery', 'continue', '--help')
    return
}
if ([string]::IsNullOrWhiteSpace($From)) {
    throw '-From 必须引用 V8 preflight full JSON。'
}
if ($Apply.IsPresent -eq $ApplyIfEligible.IsPresent) {
    throw '必须且只能选择 -Apply 或 -ApplyIfEligible。'
}
if (-not [string]::IsNullOrWhiteSpace($TokenEnvironmentVariable) -and -not [string]::IsNullOrWhiteSpace($TokenFile)) {
    throw '-TokenEnvironmentVariable 与 -TokenFile 不能同时使用。'
}

$RepoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot
$preflightPath = [System.IO.Path]::GetFullPath(
    $(if ([System.IO.Path]::IsPathRooted($From)) { $From } else { Join-Path $RepoRoot $From })
)
$operation = if ($Apply.IsPresent) { '按 V8 preflight 写回目标 PBL' } else { '在 V8 policy 与全部守卫允许时写回目标 PBL' }
if (-not $PSCmdlet.ShouldProcess($preflightPath, $operation)) {
    return
}

$cliExe = Resolve-PbBridgeCliPath -ProjectRoot $RepoRoot
$arguments = @('delivery', 'continue', '--from', $preflightPath, '--progress', $Progress)
if ($Apply.IsPresent) {
    $arguments += '--apply'
}
else {
    $arguments += '--apply-if-eligible'
}
if (-not [string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    $arguments += @('--result', $ResultJsonPath)
}
if (-not [string]::IsNullOrWhiteSpace($PolicyPath)) {
    $arguments += @('--policy', $PolicyPath)
}
if (-not [string]::IsNullOrWhiteSpace($TokenEnvironmentVariable)) {
    $arguments += @('--token-env', $TokenEnvironmentVariable)
}
if (-not [string]::IsNullOrWhiteSpace($TokenFile)) {
    $arguments += @('--token-file', $TokenFile)
}

Write-Verbose -Message "workflow=delivery-continue-v8 mode=$(if ($Apply.IsPresent) { 'apply' } else { 'apply-if-eligible' }) preflight=$preflightPath"
$commandResult = Invoke-PbBridgeNativeCommand -FilePath $cliExe -Arguments $arguments -WorkingDirectory $RepoRoot -CaptureStdout
Complete-PbBridgeNativeCommand -Result $commandResult
