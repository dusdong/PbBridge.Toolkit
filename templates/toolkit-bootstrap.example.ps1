#requires -PSEdition Core
#requires -Version 7.4

param(
    [string]$ToolkitRoot = (Join-Path $PSScriptRoot "..")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$cliExe = Join-Path $ToolkitRoot "runtime\cli\win-x86\PbBridge.Cli.exe"
$ideExe = Join-Path $ToolkitRoot "runtime\ide\win-x64\SharpIDE.exe"

if (-not (Test-Path -LiteralPath $cliExe)) {
    throw "未找到 CLI：$cliExe"
}

if (-not (Test-Path -LiteralPath $ideExe)) {
    throw "未找到 IDE：$ideExe"
}

Write-Host "CLI 路径: $cliExe"
Write-Host "IDE 路径: $ideExe"
Write-Host "正在执行 CLI doctor..."
& $cliExe doctor
