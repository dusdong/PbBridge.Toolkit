#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.0
<#
.SYNOPSIS
Runs the expert/debug V4 writeback close-loop wrapper.

.EXAMPLE
powershell -ExecutionPolicy Bypass -Command "& '.\scripts\pbbridge-writeback-close-loop.ps1' -Object @('app.pbl:window:w_one=src/app/w_one.srw','app.pbl:datawindow:d_one=src/app/d_one.srd')"

.NOTES
PowerShell wrapper 多对象必须通过 powershell -Command 传数组：-Object @('obj1','obj2')。不要在 powershell -File 下使用 -Object obj1,obj2 或重复 -Object；CLI 原生命令才使用重复 --object。
#>
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = "",
    [Alias('Objects')]
    [string[]]$Object,
    [string]$WorkspaceName = "",
    [ValidateSet('auto', 'utf-8', 'gbk', 'utf-8-bom', 'utf-16le')]
    [string]$SourceEncoding = 'auto',
    [ValidateSet('strict', 'object-source-and-target-pbl')]
    [string]$DriftPolicy = 'strict',
    [string]$ResultJsonPath = "",
    [string]$Session = "",
    [switch]$NoSessionCache,
    [int]$SessionRetentionDays = 0,
    [switch]$Apply,
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-writeback-close-loop.ps1" -CliCommand "pbbridge writeback close-loop"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @("writeback", "close-loop", "--help"); exit 0 }



function ConvertTo-SafeFileName {
    param([Parameter(Mandatory = $true)][string]$Value)

    $safe = $Value -replace '[^A-Za-z0-9_.-]', '_'
    $safe = $safe.Trim('_')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return 'object'
    }

    return $safe
}

function Get-CloseLoopObjectShortName {
    param([Parameter(Mandatory = $true)][string]$ObjectSpec)

    $objectKey = ($ObjectSpec -split '=', 2)[0]
    $parts = $objectKey -split ':'
    if ($parts.Length -gt 0 -and -not [string]::IsNullOrWhiteSpace($parts[$parts.Length - 1])) {
        return ConvertTo-SafeFileName -Value $parts[$parts.Length - 1]
    }

    return 'object'
}

function Get-Sha256Prefix {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [int]$Length = 16
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha256.ComputeHash($bytes)
        $hex = [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLowerInvariant()
        return $hex.Substring(0, [Math]::Min($Length, $hex.Length))
    }
    finally {
        $sha256.Dispose()
    }
}

$RepoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot
if ([string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    $firstObjectShortName = Get-CloseLoopObjectShortName -ObjectSpec $Object[0]
    $mode = if ($Apply.IsPresent) { 'apply' } else { 'dryrun' }
    $hashInput = (($Object -join '|') + "|workspace=$WorkspaceName|encoding=$SourceEncoding|drift=$DriftPolicy|mode=$mode")
    $hash16 = Get-Sha256Prefix -Value $hashInput -Length 16
    $ResultJsonPath = Join-Path $RepoRoot (".pbbridge\local\results\writeback-close-loop\writeback-close-loop-{0}-{1}.json" -f $firstObjectShortName, $hash16)
}
$resultPath = [System.IO.Path]::GetFullPath($ResultJsonPath)
$toolkitRoot = Join-Path $RepoRoot ".pbbridge\PbBridge.Toolkit"
$cliExe = Join-Path $toolkitRoot "runtime\cli\win-x86\PbBridge.Cli.exe"

if (-not (Test-Path -LiteralPath $cliExe -PathType Leaf)) {
    throw "未找到 CLI：$cliExe"
}

$arguments = @(
    'writeback',
    'close-loop',
    '--workspace-path', $RepoRoot,
    '--result', $resultPath,
    '--source-encoding', $SourceEncoding,
    '--drift-policy', $DriftPolicy
)

if (-not [string]::IsNullOrWhiteSpace($WorkspaceName)) {
    $arguments += @('--workspace', $WorkspaceName.Trim())
}

foreach ($item in $Object) {
    $arguments += @('--object', $item)
}

if ($Apply.IsPresent) {
    $arguments += '--apply'
}
if (-not [string]::IsNullOrWhiteSpace($Session)) {
    $arguments += @('--session', $Session)
}
if ($NoSessionCache.IsPresent) {
    $arguments += '--no-session-cache'
}
if ($SessionRetentionDays -gt 0) {
    $arguments += @('--session-retention-days', [string]$SessionRetentionDays)
}

$commandResult = Invoke-PbBridgeNativeCommand -FilePath $cliExe -Arguments $arguments -WorkingDirectory $RepoRoot -CaptureStdout
Complete-PbBridgeNativeCommand -Result $commandResult
