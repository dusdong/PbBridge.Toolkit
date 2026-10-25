#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.5.3
param(
    [Alias('ProjectRoot')]
    [string]$RepoRoot = "",
    [Alias('Workspace')]
    [string]$WorkspaceId = "",
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-bootstrap.ps1" -CliCommand "pbbridge toolkit bootstrap"; exit 0 }
if ($CliHelp.IsPresent) { Invoke-PbBridgeCliHelp -ProjectRoot $RepoRoot -Arguments @("toolkit", "bootstrap", "--help"); exit 0 }
Assert-PbBridgeWorkspaceId -WorkspaceId $WorkspaceId



function Invoke-CliJson {
    param(
        [Parameter(Mandatory = $true)][string]$CliExe,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $output = & $CliExe @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
    if ($exitCode -ne 0) {
        throw "$Label 失败，退出码：$exitCode。输出：$text"
    }

    try {
        return $text | ConvertFrom-Json
    }
    catch {
        throw "$Label 输出不是有效 JSON。输出：$text"
    }
}

function Assert-ToolkitRuntimeContract {
    param(
        [Parameter(Mandatory = $true)][string]$ToolkitRoot,
        [Parameter(Mandatory = $true)][string]$CliExe
    )

    $manifestPath = Join-Path $ToolkitRoot "manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "stale-runtime-cli: 未找到 toolkit manifest：$manifestPath"
    }

    $manifest = [System.IO.File]::ReadAllText($manifestPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $version = Invoke-CliJson -CliExe $CliExe -Arguments @("version") -Label "CLI version"
    if ([string]$version.version -ne [string]$manifest.productVersion) {
        throw "stale-runtime-cli: CLI version 与 toolkit manifest.productVersion 不一致。cli=$($version.version) manifest=$($manifest.productVersion)"
    }

    $summary = [ordered]@{
        toolkitVersion = [string]$manifest.toolkitVersion
        cliVersion = [string]$version.version
        templateVersion = [string]$manifest.externalProjectTemplateVersion
        runtimeContractStatus = "not-required"
        orcaDoctorStatus = "not-required"
        pbSpyDependencySummary = "<not-checked>"
    }

    if ($manifest.runtimeContract.orcaCandidateDoctorRequired -ne $true) {
        return [pscustomobject]$summary
    }

    $doctor = Invoke-CliJson -CliExe $CliExe -Arguments @("--adapter", "orca", "doctor") -Label "CLI orca doctor"
    $adapter = @($doctor.adapters) | Where-Object { $_.name -eq "orca" } | Select-Object -First 1
    if ($null -eq $adapter -or $null -eq $adapter.runtime) {
        throw "missing-orca-candidate-contract: CLI orca doctor 缺少 PBSpyORCA candidate runtime 证据。"
    }

    foreach ($field in @($manifest.runtimeContract.requiredDoctorFields)) {
        if (@($adapter.runtime.PSObject.Properties.Name) -notcontains [string]$field) {
            throw "missing-orca-candidate-contract: CLI orca doctor 缺少字段 $field。"
        }
    }

    $dependencyNames = @($adapter.runtime.nativeDependencies | ForEach-Object { [string]$_.name })
    $summary.runtimeContractStatus = "passed"
    $summary.orcaDoctorStatus = [string]$adapter.runtime.importSupportStatus
    $summary.pbSpyDependencySummary = if ($dependencyNames.Count -gt 0) { $dependencyNames -join ", " } else { "<none>" }
    return [pscustomobject]$summary
}

function Invoke-ToolkitUpdateCheck {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$ToolkitRoot
    )

    $updateScript = Join-Path $ToolkitRoot "templates\external-project\pbbridge-toolkit-update.ps1"
    if (-not (Test-Path -LiteralPath $updateScript -PathType Leaf)) {
        Write-Warning "未找到 Toolkit 更新检查脚本，跳过远端快照检查：$updateScript"
        return $null
    }

    try {
        $result = & $updateScript -RepoRoot $RepoRoot -ToolkitRoot $ToolkitRoot -PassThru
        if ($null -ne $result -and [string]$result.status -eq "outdated") {
            Write-Warning "Toolkit 有新快照但 bootstrap 不阻断。运行 scripts/pbbridge-toolkit-update.ps1 -Apply 更新，并提交 .pbbridge/PbBridge.Toolkit submodule 指针。"
        }
        elseif ($null -ne $result -and [string]$result.status -eq "blocked") {
            Write-Warning "Toolkit 更新检查 blocked，但 bootstrap 不阻断。请查看 .pbbridge/toolkit-update-check.json。"
        }

        return $result
    }
    catch {
        Write-Warning "Toolkit 更新检查失败但 bootstrap 不阻断：$($_.Exception.Message)"
        return $null
    }
}

$RepoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $RepoRoot
$toolkitRoot = Join-Path $RepoRoot ".pbbridge\PbBridge.Toolkit"
$cliExe = Join-Path $toolkitRoot "runtime\cli\win-x86\PbBridge.Cli.exe"
$ideExe = Join-Path $toolkitRoot "runtime\ide\win-x64\SharpIDE.exe"

if (-not (Test-Path -LiteralPath $toolkitRoot -PathType Container)) {
    throw "未找到 toolkit submodule：$toolkitRoot"
}

if (-not (Test-Path -LiteralPath $cliExe -PathType Leaf)) {
    throw "未找到 CLI：$cliExe"
}

if (-not (Test-Path -LiteralPath $ideExe -PathType Leaf)) {
    throw "未找到 IDE：$ideExe"
}

Write-Host "Toolkit 路径: $toolkitRoot"
Write-Host "CLI 路径: $cliExe"
Write-Host "IDE 路径: $ideExe"
Write-Host ("Workspace selector: {0}" -f $(if ([string]::IsNullOrWhiteSpace($WorkspaceId)) { '<由当前 CLI 自动选择唯一 workspace>' } else { $WorkspaceId }))
Write-Host "正在检查 Toolkit 远端快照..."
$toolkitUpdateSummary = Invoke-ToolkitUpdateCheck -RepoRoot $RepoRoot -ToolkitRoot $toolkitRoot
if ($null -ne $toolkitUpdateSummary) {
    Write-Host ("ToolkitUpdateStatus: {0}" -f $toolkitUpdateSummary.status)
}
Write-Host "正在执行 CLI doctor..."

& $cliExe doctor

if ($LASTEXITCODE -ne 0) {
    throw "CLI doctor 失败，退出码：$LASTEXITCODE"
}

Write-Host "正在检查 Toolkit runtime 契约..."
$runtimeSummary = Assert-ToolkitRuntimeContract -ToolkitRoot $toolkitRoot -CliExe $cliExe
Write-Host "正在检查本机目录 hygiene（只读）..."
$hygieneResultPath = Join-Path $RepoRoot ".pbbridge\local\results\hygiene\bootstrap-check.json"
$hygieneSummary = Invoke-CliJson -CliExe $cliExe -Arguments @("hygiene", "check", "--project-root", $RepoRoot, "--result", $hygieneResultPath) -Label "hygiene check"
Write-Host "Bootstrap Summary"
Write-Host ("ToolkitVersion: {0}" -f $runtimeSummary.toolkitVersion)
Write-Host ("CliVersion: {0}" -f $runtimeSummary.cliVersion)
Write-Host ("TemplateVersion: {0}" -f $runtimeSummary.templateVersion)
Write-Host ("RuntimeContractStatus: {0}" -f $runtimeSummary.runtimeContractStatus)
Write-Host ("OrcaDoctorStatus: {0}" -f $runtimeSummary.orcaDoctorStatus)
Write-Host ("PBSpyDependencySummary: {0}" -f $runtimeSummary.pbSpyDependencySummary)
Write-Host ("HygieneStatus: {0}" -f $hygieneSummary.status)
Write-Host ("HygieneProposedRuleCount: {0}" -f @($hygieneSummary.proposedRules).Count)
