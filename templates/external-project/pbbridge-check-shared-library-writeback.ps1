#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.1
param(
    [string]$ProjectRoot = "",
    [string]$WorkspaceName = "",
    [string]$SharedLibraryPath = "",
    [string]$SharedLibraryConfigPath = "",
    [string]$ParentOutputPath = "",
    [string]$SharedOutputPath = "",
    [string]$ResultJsonPath = "",
    [switch]$AllowDirtySubmodule,
    [switch]$AllowPointerUpdate,
    [switch]$AllowBlockedResult,
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-check-shared-library-writeback.ps1" -CliCommand ""; exit 0 }
if ($CliHelp.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-check-shared-library-writeback.ps1" -CliCommand ""; exit 0 }

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

$root = Resolve-ProjectRoot -ExplicitRoot $ProjectRoot
$cliArgs = @("shared-library", "writeback-check", "--project-root", $root)
if (-not [string]::IsNullOrWhiteSpace($WorkspaceName)) { $cliArgs += @("--workspace", $WorkspaceName) }
if (-not [string]::IsNullOrWhiteSpace($SharedLibraryPath)) { $cliArgs += @("--shared-library-path", $SharedLibraryPath) }
if (-not [string]::IsNullOrWhiteSpace($SharedLibraryConfigPath)) { $cliArgs += @("--shared-library-config", $SharedLibraryConfigPath) }
if (-not [string]::IsNullOrWhiteSpace($ParentOutputPath)) { $cliArgs += @("--parent-output", $ParentOutputPath) }
if (-not [string]::IsNullOrWhiteSpace($SharedOutputPath)) { $cliArgs += @("--shared-output", $SharedOutputPath) }
if (-not [string]::IsNullOrWhiteSpace($ResultJsonPath)) { $cliArgs += @("--result", $ResultJsonPath) }
if ($AllowDirtySubmodule.IsPresent) { $cliArgs += "--allow-dirty-submodule" }
if ($AllowPointerUpdate.IsPresent) { $cliArgs += "--allow-pointer-update" }
if ($AllowBlockedResult.IsPresent) { $cliArgs += "--allow-blocked-result" }

Invoke-PbBridgeCliWrapper -Root $root -Arguments $cliArgs -CommandLogName "shared-library-writeback-check"
