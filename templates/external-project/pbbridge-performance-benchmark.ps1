#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.1
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = "",
    [string]$WorkspaceName = "",
    [ValidateSet('small', 'medium', 'large', 'real')]
    [string]$Profile = 'small',
    [ValidateSet('cold', 'warm', 'both')]
    [string]$CacheMode = 'warm',
    [string[]]$Scenario = @(),
    [ValidateRange(-1, 20)]
    [int]$Iterations = -1,
    [ValidateRange(-1, 5)]
    [int]$Warmup = -1,
    [string]$DatasetManifest = "",
    [string]$ComparisonBaseline = "",
    [string]$Object = "",
    [string]$Baseline = "",
    [string]$Current = "",
    [string[]]$DeliveryObject = @(),
    [string]$ResultJsonPath = "",
    [ValidateNotNullOrEmpty()]
    [string]$RunnerClassId = 'pbbridge-toolkit-win-x86',
    [ValidateNotNullOrEmpty()]
    [string]$CliLaunchShape = 'native-executable',
    [ValidateNotNullOrEmpty()]
    [string]$RuntimeFlavor = 'dotnet-native-aot',
    [ValidateNotNullOrEmpty()]
    [string]$MeasurementHarnessVersion = 'pbbridge-runtime-benchmark-v2.1',
    [switch]$RedactPaths,
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



$wrapperStart = [System.Diagnostics.Stopwatch]::StartNew()
$RepoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-performance-benchmark.ps1" -CliCommand "pbbridge performance benchmark"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @("performance", "benchmark", "--help"); exit 0 }
if ([string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    $ResultJsonPath = Join-Path $RepoRoot ".pbbridge\local\results\runtime-benchmark.json"
}
$toolkitRoot = Join-Path $RepoRoot ".pbbridge\PbBridge.Toolkit"
$cliExe = Join-Path $toolkitRoot "runtime\cli\win-x86\PbBridge.Cli.exe"

if (-not (Test-Path -LiteralPath $cliExe -PathType Leaf)) {
    throw "未找到 CLI：$cliExe"
}

$arguments = @(
    'performance', 'benchmark',
    '--project-root', $RepoRoot,
    '--profile', $Profile,
    '--cache-mode', $CacheMode,
    '--result', ([System.IO.Path]::GetFullPath($ResultJsonPath)),
    '--launcher', 'powershell-wrapper',
    '--runner-class-id', $RunnerClassId,
    '--cli-launch-shape', $CliLaunchShape,
    '--runtime-flavor', $RuntimeFlavor,
    '--measurement-harness-version', $MeasurementHarnessVersion
)
if ($Iterations -ge 0) { $arguments += @('--iterations', ([string]$Iterations)) }
if ($Warmup -ge 0) { $arguments += @('--warmup', ([string]$Warmup)) }
if (-not [string]::IsNullOrWhiteSpace($DatasetManifest)) { $arguments += @('--dataset-manifest', ([System.IO.Path]::GetFullPath($DatasetManifest))) }
if (-not [string]::IsNullOrWhiteSpace($ComparisonBaseline)) { $arguments += @('--comparison-baseline', ([System.IO.Path]::GetFullPath($ComparisonBaseline))) }
if (-not [string]::IsNullOrWhiteSpace($WorkspaceName)) {
    $arguments += @('--workspace', $WorkspaceName.Trim())
}
foreach ($item in $Scenario) {
    if (-not [string]::IsNullOrWhiteSpace($item)) { $arguments += @('--scenario', $item) }
}
foreach ($item in $DeliveryObject) {
    if (-not [string]::IsNullOrWhiteSpace($item)) { $arguments += @('--delivery-object', $item) }
}
if (-not [string]::IsNullOrWhiteSpace($Object)) { $arguments += @('--object', $Object) }
if (-not [string]::IsNullOrWhiteSpace($Baseline)) { $arguments += @('--baseline', $Baseline) }
if (-not [string]::IsNullOrWhiteSpace($Current)) { $arguments += @('--current', $Current) }
if ($RedactPaths.IsPresent) { $arguments += '--redact-paths' }

$wrapperStart.Stop()
$arguments += @('--wrapper-overhead-ms', ([string]$wrapperStart.ElapsedMilliseconds))

& $cliExe @arguments
exit $LASTEXITCODE
