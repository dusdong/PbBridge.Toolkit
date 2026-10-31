#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.1
<#
.SYNOPSIS
运行 V8 delivery 纯预检。

.DESCRIPTION
该 wrapper 只负责标准参数与 CLI 流式调用。它不会执行 Apply；冲突、目标快照、事实新鲜度和 readiness 均由 V8 CLI/application 评估。

.EXAMPLE
.\scripts\pbbridge-delivery-close-loop.ps1 -RepoRoot . -Workspace canyin -Object 'app.pbl:window:w_main=src/w_main.srw'

.OUTPUTS
CLI 生成的 pbbridge-v8-compact-summary JSON；完整 preflight 由 -ResultJsonPath 指定。
operationAssessments 只解释五种操作的事实范围；全局同步或发布阻断不能替代目标对象 preflight。
nextAction.type 为 command 时才可复制命令，manual-action 保留为人工说明。
#>
[CmdletBinding()]
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = '',

    [Alias('Workspace')]
    [string]$WorkspaceId = '',

    [Alias('Objects')]
    [string[]]$Object = @(),

    [string]$ResultJsonPath = '',
    [string]$PolicyPath = '',
    [string]$TokenEnvironmentVariable = '',
    [string]$TokenFile = '',
    [string]$Session = '',

    [ValidateSet('auto', 'none', 'text', 'jsonl')]
    [string]$Progress = 'auto',

    [switch]$ContinueIndependentBatches,
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
    Show-PbBridgeWrapperHelp -WrapperName 'pbbridge-delivery-close-loop.ps1' -CliCommand 'pbbridge delivery close-loop'
    return
}
if ($CliHelp.IsPresent) {
    Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @('delivery', 'close-loop', '--help')
    return
}
if ($Object.Count -eq 0 -or @($Object | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -ne $Object.Count) {
    throw '-Object 至少需要一个非空对象映射；Help/CliHelp 无需提供 Object。'
}
if (-not [string]::IsNullOrWhiteSpace($TokenEnvironmentVariable) -and -not [string]::IsNullOrWhiteSpace($TokenFile)) {
    throw '-TokenEnvironmentVariable 与 -TokenFile 不能同时使用。'
}
Assert-PbBridgeWorkspaceId -WorkspaceId $WorkspaceId

$RepoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot
$cliExe = Resolve-PbBridgeCliPath -ProjectRoot $RepoRoot
$arguments = @('delivery', 'close-loop', '--repo-root', $RepoRoot, '--progress', $Progress)
if (-not [string]::IsNullOrWhiteSpace($WorkspaceId)) {
    $arguments += @('--workspace', $WorkspaceId)
}
foreach ($item in $Object) {
    $arguments += @('--object', $item)
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
if (-not [string]::IsNullOrWhiteSpace($Session)) {
    $arguments += @('--session', $Session)
}
if ($ContinueIndependentBatches.IsPresent) {
    $arguments += '--continue-independent-batches'
}

Write-Verbose -Message "workflow=delivery-close-loop-v8 mode=preflight workspace=$WorkspaceId"
$commandResult = Invoke-PbBridgeNativeCommand -FilePath $cliExe -Arguments $arguments -WorkingDirectory $RepoRoot -CaptureStdout
Complete-PbBridgeNativeCommand -Result $commandResult
