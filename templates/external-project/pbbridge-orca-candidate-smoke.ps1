#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.0
[CmdletBinding()]
param(
    [string]$ProjectRoot = "",
    [string]$OutputPath = "",
    [string]$PlanJsonPath = "",
    [string]$ResultJsonPath = "",
    [switch]$UseExistingPlan,
    [switch]$Apply,
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-orca-candidate-smoke.ps1" -CliCommand ""; exit 0 }
if ($CliHelp.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-orca-candidate-smoke.ps1" -CliCommand ""; exit 0 }

function Resolve-ProjectRoot {
    param([string]$ExplicitRoot)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitRoot)) {
        return (Resolve-Path -LiteralPath $ExplicitRoot).Path
    }

    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Invoke-CliJson {
    param(
        [Parameter(Mandatory = $true)][string]$CliExe,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $output = & $CliExe @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
    $json = $null
    if ($exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($text)) {
        try { $json = $text | ConvertFrom-Json } catch { $json = $null }
    }

    return [pscustomobject]@{
        exitCode = $exitCode
        output = $text
        json = $json
    }
}

function Get-OrcaRuntimeEvidence {
    param([Parameter(Mandatory = $true)]$Doctor)

    $adapter = @($Doctor.adapters) | Where-Object { $_.name -eq "orca" } | Select-Object -First 1
    if ($null -eq $adapter) {
        return $null
    }

    return $adapter.runtime
}

function Test-OrcaRuntimeEvidence {
    param($Runtime)

    if ($null -eq $Runtime) {
        return $false
    }

    $fields = @($Runtime.PSObject.Properties.Name)
    foreach ($field in @("adapterFamily", "pbVersion", "runtimeSource", "encodingMode", "x86Status", "importSupportStatus")) {
        if ($fields -notcontains $field) {
            return $false
        }
    }

    return [string]$Runtime.adapterFamily -eq "pbspy-orca" -and
        [int]$Runtime.pbVersion -eq 90 -and
        [string]$Runtime.importSupportStatus -eq "candidate"
}

function New-SmokeResult {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$Message
    )

    [ordered]@{
        schemaName = "pbbridge-orca-candidate-smoke"
        generatedAt = [DateTimeOffset]::Now.ToString("o")
        status = $Status
        message = $Message
        projectRoot = $script:projectRoot
        outputPath = $script:outputRoot
        planJsonPath = $script:activePlanJsonPath
        applyRequested = [bool]$Apply
        doctor = $script:doctorEvidence
        dryRun = $script:dryRunEvidence
        apply = $script:applyEvidence
        diagnostics = @($script:diagnostics)
    }
}

$script:projectRoot = Resolve-ProjectRoot -ExplicitRoot $ProjectRoot
$script:outputRoot = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    Join-Path $script:projectRoot ".pbbridge\workspaces\default\artifacts\pbbridge"
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $script:projectRoot $OutputPath))
}
$script:activePlanJsonPath = if (-not [string]::IsNullOrWhiteSpace($PlanJsonPath)) {
    [System.IO.Path]::GetFullPath((Join-Path $script:projectRoot $PlanJsonPath))
}
else {
    Join-Path $script:outputRoot "plan-import.json"
}
$script:doctorEvidence = $null
$script:dryRunEvidence = $null
$script:applyEvidence = $null
$script:diagnostics = [System.Collections.Generic.List[object]]::new()

$resultPath = if ([string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    Join-Path $script:projectRoot ".pbbridge\orca-candidate-smoke.json"
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $script:projectRoot $ResultJsonPath))
}

$cliExe = Join-Path $script:projectRoot ".pbbridge\PbBridge.Toolkit\runtime\cli\win-x86\PbBridge.Cli.exe"
if (-not (Test-Path -LiteralPath $cliExe -PathType Leaf)) {
    $result = New-SmokeResult -Status "blocked-by-environment" -Message "未找到 Toolkit CLI。"
    Write-JsonFile -Path $resultPath -Value $result
    if (-not $AllowBlockedResult.IsPresent) { throw $result.message }
    return
}

$doctor = Invoke-CliJson -CliExe $cliExe -Arguments @("--adapter", "orca", "doctor")
$runtime = if ($null -ne $doctor.json) { Get-OrcaRuntimeEvidence -Doctor $doctor.json } else { $null }
$script:doctorEvidence = [ordered]@{
    exitCode = $doctor.exitCode
    runtime = $runtime
    output = $doctor.output
}

if ($doctor.exitCode -ne 0 -or -not (Test-OrcaRuntimeEvidence -Runtime $runtime)) {
    $result = New-SmokeResult -Status "blocked-by-environment" -Message "ORCA candidate doctor 未满足准入证据。"
    Write-JsonFile -Path $resultPath -Value $result
    if (-not $AllowBlockedResult.IsPresent) { throw $result.message }
    return
}

if (-not (Test-Path -LiteralPath $script:activePlanJsonPath -PathType Leaf)) {
    $result = New-SmokeResult -Status "blocked-by-writeback" -Message "未找到 import plan，无法执行 ORCA candidate DryRun。"
    Write-JsonFile -Path $resultPath -Value $result
    if (-not $AllowBlockedResult.IsPresent) { throw $result.message }
    return
}

$dryRunJsonPath = Join-Path $script:outputRoot "import-result.orca-smoke.dryrun.json"
$dryRun = Invoke-CliJson -CliExe $cliExe -Arguments @("--adapter", "orca", "import", $script:activePlanJsonPath, $dryRunJsonPath, "DryRun", "block", "--writeback")
$script:dryRunEvidence = [ordered]@{
    exitCode = $dryRun.exitCode
    resultJsonPath = $dryRunJsonPath
    output = $dryRun.output
}

if ($dryRun.exitCode -ne 0) {
    $result = New-SmokeResult -Status "blocked-by-writeback" -Message "ORCA candidate DryRun 失败。"
    Write-JsonFile -Path $resultPath -Value $result
    if (-not $AllowBlockedResult.IsPresent) { throw $result.message }
    return
}

if (-not $Apply.IsPresent) {
    $result = New-SmokeResult -Status "candidate-evidence-collected" -Message "已收集 ORCA candidate doctor 与 DryRun 证据，未执行 Apply。"
    Write-JsonFile -Path $resultPath -Value $result
    Write-Host "ORCA candidate smoke evidence: $resultPath"
    return
}

$applyJsonPath = Join-Path $script:outputRoot "import-result.orca-smoke.apply.json"
$applyResult = Invoke-CliJson -CliExe $cliExe -Arguments @("--adapter", "orca", "import", $script:activePlanJsonPath, $applyJsonPath, "Apply", "block", "--writeback", "--post-apply-review")
$script:applyEvidence = [ordered]@{
    exitCode = $applyResult.exitCode
    resultJsonPath = $applyJsonPath
    output = $applyResult.output
}

if (Test-Path -LiteralPath $applyJsonPath -PathType Leaf) {
    $applyJson = Read-JsonFile -Path $applyJsonPath
    $script:applyEvidence["result"] = $applyJson
    foreach ($path in @($applyJson.diagnosticsBundleJsonPath, $applyJson.rollbackResultJsonPath)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$path)) {
            $script:diagnostics.Add([string]$path) | Out-Null
        }
    }
}

if ($applyResult.exitCode -ne 0) {
    $result = New-SmokeResult -Status "blocked-by-writeback" -Message "ORCA candidate Apply 失败，详见 import result、rollback 和 diagnostics。"
    Write-JsonFile -Path $resultPath -Value $result
    if (-not $AllowBlockedResult.IsPresent) { throw $result.message }
    return
}

$result = New-SmokeResult -Status "clear" -Message "ORCA candidate Apply 已完成，请继续执行 re-export、verify、diff 或 PowerBuilder IDE 验收。"
Write-JsonFile -Path $resultPath -Value $result
Write-Host "ORCA candidate smoke evidence: $resultPath"
