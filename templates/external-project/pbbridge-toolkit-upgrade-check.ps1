#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.0
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = "",
    [Alias('Workspace')]
    [string]$WorkspaceId = "",
    [string]$SmokeObject = "",
    [ValidateSet("recommended", "all", "none")]
    [string]$WrapperSmokeScope = "recommended",
    [switch]$StrictGitHygiene,
    [string]$ResultJsonPath = "",
    [string]$ReleaseRecordPath = "",
    [string]$PublicationReceiptPath = "",
    [string]$RecoveryArtifactRoot = "",
    [string]$RecoveryExtractionRoot = "",
    [string]$SnapshotPreviewPath = "",
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

if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-toolkit-upgrade-check.ps1" -CliCommand ""; exit 0 }
if ($CliHelp.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-toolkit-upgrade-check.ps1" -CliCommand ""; exit 0 }
$RepoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot
Assert-PbBridgeRequiredParameter -Name 'WorkspaceId' -Value $WorkspaceId
Assert-PbBridgeWorkspaceId -WorkspaceId $WorkspaceId
$toolkitRoot = Join-Path $RepoRoot ".pbbridge\PbBridge.Toolkit"
$cliExe = Join-Path $toolkitRoot "runtime\cli\win-x86\PbBridge.Cli.exe"

if (-not (Test-Path -LiteralPath $cliExe -PathType Leaf)) {
    throw "未找到 CLI：$cliExe"
}

$arguments = @(
    'toolkit-upgrade-check',
    '--repo-root', $RepoRoot,
    '--workspace', $WorkspaceId,
    '--wrapper-smoke-scope', $WrapperSmokeScope
)
if (-not [string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    $arguments += @('--result', $ResultJsonPath)
}
if (-not [string]::IsNullOrWhiteSpace($SmokeObject)) {
    $arguments += @('--smoke-object', $SmokeObject)
}
if ($StrictGitHygiene.IsPresent) {
    $arguments += '--strict-git-hygiene'
}

if ($ReleaseRecordPath -or $RecoveryArtifactRoot -or $RecoveryExtractionRoot -or $SnapshotPreviewPath) {
    if (-not $ReleaseRecordPath -or -not $RecoveryArtifactRoot -or -not $RecoveryExtractionRoot -or -not $SnapshotPreviewPath) {
        throw '恢复预览需要 ReleaseRecordPath、RecoveryArtifactRoot、RecoveryExtractionRoot 和独立 SnapshotPreviewPath。'
    }
    # This is an explicit read-only preview. It never requests Apply.
    $preview = & (Join-Path $PSScriptRoot 'pbbridge-toolkit-update.ps1') -RepoRoot $RepoRoot `
        -ReleaseRecordPath $ReleaseRecordPath -PublicationReceiptPath $PublicationReceiptPath -RecoveryArtifactRoot $RecoveryArtifactRoot `
        -RecoveryExtractionRoot $RecoveryExtractionRoot -ResultPath $SnapshotPreviewPath -PassThru
    Write-Verbose "快照身份与恢复预览：$SnapshotPreviewPath；recovery=$($preview.recovery.status)"
}

$commandResult = Invoke-PbBridgeNativeCommand -FilePath $cliExe -Arguments $arguments -WorkingDirectory $RepoRoot -CaptureStdout
Complete-PbBridgeNativeCommand -Result $commandResult
