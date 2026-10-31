#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.1
param(
    [string]$ProjectRoot = "",
    [string]$WorkspaceName = "",
    [string]$WorkspacePath = "",
    [string]$ResultJsonPath = "",
    [string]$BaselineOutputPath = "",
    [ValidateSet("beside-pbl-src")]
    [string]$SourceLayout = "",
    [ValidateSet("workspace-targets", "all-targets", "all-pbl")]
    [string]$ScanScope = "",
    [string[]]$IncludeLibrary = @(),
    [string[]]$ExcludeLibrary = @(),
    [ValidateSet("Disabled", "UseExisting", "RequireExisting")]
    [string]$VerifyPolicyMode = "",
    [string]$VerifyBaselinePath = "",
    [string[]]$VerifyWaiverPath = @(),
    [switch]$IncrementalRefresh,
    [switch]$ProjectionOnly,
    [string[]]$RefreshLibrary = @(),
    [string[]]$RefreshObjectKey = @(),
    [string]$PreviousArtifactsPath = "",
    [switch]$AllowDeleteProjection,
    [switch]$AllowBlockedResult,
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-pbl-change-intake.ps1" -CliCommand "pbbridge pbl change-intake"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $ProjectRoot -Arguments @("pbl", "change-intake", "--help"); exit 0 }

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

$root = Resolve-ProjectRoot -ExplicitRoot $ProjectRoot
$cliArgs = @("pbl", "change-intake", "--project-root", $root)
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
if (-not [string]::IsNullOrWhiteSpace($VerifyPolicyMode)) { $cliArgs += @("--verify-policy-mode", $VerifyPolicyMode) }
if (-not [string]::IsNullOrWhiteSpace($VerifyBaselinePath)) { $cliArgs += @("--verify-baseline", $VerifyBaselinePath) }
foreach ($path in @($VerifyWaiverPath)) {
    if (-not [string]::IsNullOrWhiteSpace($path)) { $cliArgs += @("--verify-waiver", $path) }
}
if ($IncrementalRefresh.IsPresent) { $cliArgs += "--incremental-refresh" }
if ($ProjectionOnly.IsPresent) { $cliArgs += "--projection-only" }
foreach ($library in @($RefreshLibrary)) {
    if (-not [string]::IsNullOrWhiteSpace($library)) { $cliArgs += @("--refresh-library", $library) }
}
foreach ($objectKey in @($RefreshObjectKey)) {
    if (-not [string]::IsNullOrWhiteSpace($objectKey)) { $cliArgs += @("--refresh-object-key", $objectKey) }
}
if (-not [string]::IsNullOrWhiteSpace($PreviousArtifactsPath)) { $cliArgs += @("--previous-artifacts", $PreviousArtifactsPath) }
if ($AllowDeleteProjection.IsPresent) { $cliArgs += "--allow-delete-projection" }
if ($AllowBlockedResult.IsPresent) { $cliArgs += "--allow-blocked-result" }
if ($Compact.IsPresent) { $cliArgs += "--compact" }

$cliExe = Join-Path $root ".pbbridge\PbBridge.Toolkit\runtime\cli\win-x86\PbBridge.Cli.exe"
if (-not (Test-Path -LiteralPath $cliExe -PathType Leaf)) {
    throw "未找到 PbBridge.Cli.exe：请先安装或升级 Toolkit runtime。"
}

$commandResult = Invoke-PbBridgeNativeCommand -FilePath $cliExe -Arguments $cliArgs -WorkingDirectory $root -CaptureStdout
Complete-PbBridgeNativeCommand -Result $commandResult
