#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.5.3
param(
    [string]$ProjectRoot = "",
    [string]$WorkspaceName = "",
    [string]$ResultJsonPath = "",
    [switch]$RefreshReadonlyEvidence,
    [switch]$AllowNoRemote,
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-project-health.ps1" -CliCommand "pbbridge project health"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $ProjectRoot -Arguments @("project", "health", "--help"); exit 0 }

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
$cliArgs = @("project", "health", "--project-root", $root)
if (-not [string]::IsNullOrWhiteSpace($WorkspaceName)) { $cliArgs += @("--workspace", $WorkspaceName.Trim()) }
if (-not [string]::IsNullOrWhiteSpace($ResultJsonPath)) { $cliArgs += @("--result", $ResultJsonPath) }
if ($RefreshReadonlyEvidence.IsPresent) { $cliArgs += "--refresh-readonly-evidence" }
if ($AllowNoRemote.IsPresent) { $cliArgs += "--allow-no-remote" }
if ($Compact.IsPresent) { $cliArgs += "--compact" }

Invoke-PbBridgeCliWrapper -Root $root -Arguments $cliArgs -CommandLogName "project-health"
