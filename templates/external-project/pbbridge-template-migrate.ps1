#requires -PSEdition Core
#requires -Version 7.4

[CmdletBinding(DefaultParameterSetName = 'Plan', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Alias('RepoRoot')]
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$ToolkitRoot = '',
    [string]$WorkspaceId = 'default',
    [string]$PbwPath = '',
    [string]$OutputPath = '',
    [Parameter(ParameterSetName = 'Plan')][switch]$Plan,
    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')][switch]$Apply,
    [Parameter(Mandatory = $true, ParameterSetName = 'Decide')][switch]$Decide,
    [Parameter(ParameterSetName = 'Apply')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Decide')]
    [string]$PlanHash = '',
    [Parameter(Mandatory = $true, ParameterSetName = 'Decide')]
    [Alias('Path')]
    [string[]]$DecisionPath,
    [Parameter(Mandatory = $true, ParameterSetName = 'Decide')]
    [string]$Reason,
    [Parameter(ParameterSetName = 'Decide')]
    [string]$Actor = '',
    [switch]$Help,
    [switch]$CliHelp,
    [ValidateSet('none', 'candidate-syntax', 'candidate-identity', 'file-locked', 'write-truncated', 'post-install-hash', 'rollback-failure')]
    [string]$FailureInjection = 'none',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArguments = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:ProductVersion = '7.5.3'

if ($Help.IsPresent -or $CliHelp.IsPresent) {
    @'
PbBridge V7 template migration

Plan:   pbbridge-template-migrate.ps1 -ProjectRoot <path> [-ToolkitRoot <path>] [-WorkspaceId <id>] [-PbwPath <path>]
Decide: pbbridge-template-migrate.ps1 -ProjectRoot <path> -Decide -PlanHash <hash> -DecisionPath <path> -Reason <text>
Apply:  pbbridge-template-migrate.ps1 -ProjectRoot <path> -Apply -PlanHash <hash>

-RepoRoot remains an alias of -ProjectRoot. After the bootstrap pair is installed, the project scripts entrypoint discovers .pbbridge/PbBridge.Toolkit automatically.
'@
    exit 0
}

function Test-PbBridgeToolkitRoot {
    param([Parameter(Mandatory = $true)][string]$Candidate)

    $full = [System.IO.Path]::GetFullPath($Candidate)
    $manifestPath = Join-Path $full 'templates\external-project\template-manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return $null }
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ([string]$manifest.schemaName -ne 'pbbridge-external-project-template' -or
            [string]$manifest.templateVersion -ne $script:ProductVersion) { return $null }
        return $full
    }
    catch { return $null }
}

function Write-PbBridgeToolkitRootFailure {
    $result = [ordered]@{
        schemaName = 'pbbridge-v7-template-migration'
        schemaVersion = 8
        productVersion = $script:ProductVersion
        generatedAt = [DateTimeOffset]::UtcNow.ToString('O')
        phase = 'plan'
        outcome = 'blocked'
        projectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
        manualMigrations = @([ordered]@{
            file = 'scripts/pbbridge-template-migrate.ps1'
            code = 'template-migration-toolkit-root-not-found'
            message = '无法按显式参数、项目 .pbbridge/PbBridge.Toolkit 或 canonical Toolkit 模板入口解析 ToolkitRoot。'
        })
        nextAction = '从当前 Toolkit canonical templates/external-project 入口执行首次迁移，或显式传入有效 -ToolkitRoot。'
    }
    $result | ConvertTo-Json -Depth 20
}
if (@($RemainingArguments | Where-Object { $_ -eq '-AcceptReviewedCustomizations' }).Count -gt 0) {
    [Console]::Error.WriteLine('旧 -AcceptReviewedCustomizations 已删除；请先运行 -Plan，再用 -Decide -PlanHash <hash> -DecisionPath <path> -Reason <reason>，最后运行 -Apply -PlanHash <hash>。')
    exit 2
}
if (@($RemainingArguments).Count -gt 0) {
    [Console]::Error.WriteLine("无法识别迁移参数：$($RemainingArguments -join ' ')。请使用 Plan/Decide/Apply 协议。")
    exit 2
}
if ([string]::IsNullOrWhiteSpace($ToolkitRoot)) {
    $projectToolkitRoot = Join-Path ([System.IO.Path]::GetFullPath($ProjectRoot)) '.pbbridge\PbBridge.Toolkit'
    $ToolkitRoot = Test-PbBridgeToolkitRoot -Candidate $projectToolkitRoot
    if ([string]::IsNullOrWhiteSpace($ToolkitRoot)) {
        $canonicalManifestPath = Join-Path $PSScriptRoot 'template-manifest.json'
        if (Test-Path -LiteralPath $canonicalManifestPath -PathType Leaf) {
            $ToolkitRoot = Test-PbBridgeToolkitRoot -Candidate (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
        }
    }
}
else {
    $ToolkitRoot = Test-PbBridgeToolkitRoot -Candidate $ToolkitRoot
}
if ([string]::IsNullOrWhiteSpace($ToolkitRoot)) {
    Write-PbBridgeToolkitRootFailure
    exit 10
}
$modulePath = Join-Path $PSScriptRoot 'PbBridge.TemplateMigration.psm1'
Import-Module -Name $modulePath -Force

$invoke = @{
    ProjectRoot = $ProjectRoot
    ToolkitRoot = $ToolkitRoot
    WorkspaceId = $WorkspaceId
    PbwPath = $PbwPath
    OutputPath = $OutputPath
    FailureInjection = $FailureInjection
    Confirm = $false
}
if ($PSBoundParameters.ContainsKey('WhatIf')) {
    $invoke.WhatIf = [bool]$PSBoundParameters['WhatIf']
}
if ($Apply.IsPresent) {
    $invoke.Apply = $true
    if (-not [string]::IsNullOrWhiteSpace($PlanHash)) { $invoke.PlanHash = $PlanHash }
}
elseif ($Decide.IsPresent) {
    $invoke.Decide = $true
    $invoke.PlanHash = $PlanHash
    $invoke.DecisionPath = $DecisionPath
    $invoke.Reason = $Reason
    $invoke.Actor = $Actor
}
else {
    $invoke.Plan = $true
}
$result = Invoke-PbBridgeTemplateMigration @invoke
$result | ConvertTo-Json -Depth 20

if ($result.outcome -in @('blocked', 'awaiting-decisions', 'blocked-incompatible-customization')) { exit 10 }
if ($result.outcome -in @('rolled-back', 'recovery-required')) { exit 11 }
exit 0
