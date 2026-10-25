#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.5.3
param(
    [string]$WorkspacePath = "",
    [Alias('ProjectRoot')]
    [string]$RepoRoot = "",
    [string]$WorkspaceName = "",
    [string]$ResultJsonPath = "",
    [string]$BaselineOutputPath = "",
    [ValidateSet("beside-pbl-src")]
    [string]$SourceLayout = "",
    [ValidateSet("workspace-targets", "all-targets", "all-pbl")]
    [string]$ScanScope = "",
    [string[]]$IncludeLibrary = @(),
    [string[]]$ExcludeLibrary = @(),
    [string]$SourceHygienePolicyPath = "",
    [ValidateSet("Disabled", "UseExisting", "RequireExisting")]
    [string]$VerifyPolicyMode = "",
    [string]$VerifyBaselinePath = "",
    [string[]]$VerifyWaiverPath = @(),
    [switch]$IncrementalRefresh,
    [string[]]$RefreshLibrary = @(),
    [string[]]$RefreshObjectKey = @(),
    [string]$PreviousArtifactsPath = "",
    [switch]$SummaryOnly,
    [switch]$Compact,
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-readonly-sync.ps1" -CliCommand "pbbridge workspace readonly-sync"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @("workspace", "readonly-sync", "--help"); exit 0 }

function Resolve-ProjectRoot {
    param([string]$ExplicitRoot)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitRoot)) {
        return [System.IO.Path]::GetFullPath($ExplicitRoot)
    }

    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
    }

    return [System.IO.Path]::GetFullPath((Get-Location).Path)
}

function Invoke-PbBridgeCliWrapper {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$CommandLogName
    )

    $cliExe = Resolve-PbBridgeCliPath -ProjectRoot $Root
    $commandResult = Invoke-PbBridgeNativeCommand -FilePath $cliExe -Arguments $Arguments -WorkingDirectory $Root -CaptureStdout
    Complete-PbBridgeNativeCommand -Result $commandResult
}

$root = Resolve-ProjectRoot -ExplicitRoot $RepoRoot
$cliArgs = @("workspace", "readonly-sync", "--project-root", $root)
if (-not [string]::IsNullOrWhiteSpace($WorkspaceName)) { $cliArgs += @("--workspace", $WorkspaceName.Trim()) }
if (-not [string]::IsNullOrWhiteSpace($WorkspacePath)) { $cliArgs += @("--workspace-path", $WorkspacePath) }
if (-not [string]::IsNullOrWhiteSpace($ResultJsonPath)) { $cliArgs += @("--result", $ResultJsonPath) }
if (-not [string]::IsNullOrWhiteSpace($BaselineOutputPath)) { $cliArgs += @("--baseline-output", $BaselineOutputPath) }
if (-not [string]::IsNullOrWhiteSpace($SourceLayout)) { $cliArgs += @("--source-layout", $SourceLayout) }
if (-not [string]::IsNullOrWhiteSpace($ScanScope)) { $cliArgs += @("--scan-scope", $ScanScope) }
foreach ($pattern in @($IncludeLibrary)) {
    if (-not [string]::IsNullOrWhiteSpace($pattern)) { $cliArgs += @("--include-library", $pattern) }
}
foreach ($pattern in @($ExcludeLibrary)) {
    if (-not [string]::IsNullOrWhiteSpace($pattern)) { $cliArgs += @("--exclude-library", $pattern) }
}
if (-not [string]::IsNullOrWhiteSpace($SourceHygienePolicyPath)) { $cliArgs += @("--source-hygiene-policy", $SourceHygienePolicyPath) }
if (-not [string]::IsNullOrWhiteSpace($VerifyPolicyMode)) { $cliArgs += @("--verify-policy-mode", $VerifyPolicyMode) }
if (-not [string]::IsNullOrWhiteSpace($VerifyBaselinePath)) { $cliArgs += @("--verify-baseline", $VerifyBaselinePath) }
foreach ($path in @($VerifyWaiverPath)) {
    if (-not [string]::IsNullOrWhiteSpace($path)) { $cliArgs += @("--verify-waiver", $path) }
}
if ($IncrementalRefresh.IsPresent) { $cliArgs += "--incremental-refresh" }
foreach ($library in @($RefreshLibrary)) {
    if (-not [string]::IsNullOrWhiteSpace($library)) { $cliArgs += @("--refresh-library", $library) }
}
foreach ($objectKey in @($RefreshObjectKey)) {
    if (-not [string]::IsNullOrWhiteSpace($objectKey)) { $cliArgs += @("--refresh-object-key", $objectKey) }
}
if (-not [string]::IsNullOrWhiteSpace($PreviousArtifactsPath)) { $cliArgs += @("--previous-artifacts", $PreviousArtifactsPath) }
if ($SummaryOnly.IsPresent) { $cliArgs += "--summary-only" }
if ($Compact.IsPresent) { $cliArgs += "--compact" }

Invoke-PbBridgeCliWrapper -Root $root -Arguments $cliArgs -CommandLogName "readonly-sync"
