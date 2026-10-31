#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.6.1
[CmdletBinding()]
param(
    [string]$ProjectRoot = "",
    [string]$WorkspaceName = "",
    [string]$WorkspacePath = "",
    [ValidateNotNullOrEmpty()]
    [string[]]$PblPath,
    [ValidateSet("powerbuilder-compile-options", "project-options", "metadata-only-reviewed", "other-reviewed")]
    [string]$ReasonCode,
    [ValidateNotNullOrEmpty()]
    [string]$Reason,
    [string]$ReviewedBy = "",
    [string]$ReviewedAt = "",
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-pbl-binary-baseline.ps1" -CliCommand ""; exit 0 }
if ($CliHelp.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-pbl-binary-baseline.ps1" -CliCommand ""; exit 0 }
Assert-PbBridgeRequiredParameter -Name "ReasonCode" -Value $ReasonCode
Assert-PbBridgeRequiredParameter -Name "Reason" -Value $Reason



function Resolve-PbBridgeWorkspaceName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "必须显式提供 -WorkspaceName <id>；本地策略路径必须绑定明确 workspace。"
    }

    $normalized = $Name.Trim().ToLowerInvariant()
    if ($normalized -notmatch '^[a-z0-9_-]+$') {
        throw "WorkspaceName 只能包含小写字母、数字、- 和 _：$Name"
    }

    return $normalized
}

function ConvertTo-NormalizedRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PathValue
    )

    $value = $PathValue.Trim()
    if ([System.IO.Path]::IsPathRooted($value)) {
        $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        $fullPath = [System.IO.Path]::GetFullPath($value)
        if ($fullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $fullPath.Substring($root.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar).Replace('\', '/')
        }
    }

    return $value.Replace('\', '/')
}

function Read-PolicyFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{
            schemaName = "pbbridge-pbl-binary-baselines/v2"
            entries = @()
        }
    }

    $policy = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    if ([string]$policy.schemaName -ne "pbbridge-pbl-binary-baselines/v2") {
        throw "旧 baseline 只允许历史查看；请重新登记包含逐 PBL expectedSha256 的 pbbridge-pbl-binary-baselines/v2。actual=$($policy.schemaName)"
    }

    return $policy
}

$repoRoot = Resolve-TemplateProjectRoot -ExplicitRoot $ProjectRoot
$workspaceRootName = Resolve-PbBridgeWorkspaceName -Name $WorkspaceName
$policyPath = Join-Path $repoRoot ".pbbridge\policies\pbl-binary-baselines.json"
$normalizedPblPaths = @($PblPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
    ConvertTo-NormalizedRelativePath -RepoRoot $repoRoot -PathValue $_
} | Sort-Object -Unique)

if ($normalizedPblPaths.Count -eq 0) {
    throw "至少需要一个 PblPath。"
}

$pblFacts = @($normalizedPblPaths | ForEach-Object {
    $relativePath = $_
    $absolutePath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $relativePath))
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "PBL 不存在，无法登记精确 baseline：$relativePath"
    }

    [pscustomobject]@{
        path = $relativePath
        expectedSha256 = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
})

if ([string]::IsNullOrWhiteSpace($ReviewedBy)) {
    $ReviewedBy = if (-not [string]::IsNullOrWhiteSpace($env:GIT_AUTHOR_NAME)) { $env:GIT_AUTHOR_NAME } else { [Environment]::UserName }
}

if ([string]::IsNullOrWhiteSpace($ReviewedAt)) {
    $ReviewedAt = [DateTimeOffset]::UtcNow.ToString("o")
}

$normalizedWorkspacePath = if ([string]::IsNullOrWhiteSpace($WorkspacePath)) {
    ""
}
else {
    ConvertTo-NormalizedRelativePath -RepoRoot $repoRoot -PathValue $WorkspacePath
}

$policy = Read-PolicyFile -Path $policyPath
$newEntryKey = "{0}|{1}|{2}|{3}" -f $workspaceRootName, $normalizedWorkspacePath, (($normalizedPblPaths | Sort-Object) -join ';'), $ReasonCode
$entries = @($policy.entries | Where-Object {
    $entryWorkspace = Resolve-PbBridgeWorkspaceName -Name ([string]$_.workspaceName)
    $entryWorkspacePath = [string]$_.workspacePath
    $entryPblPaths = @($_.pbls | ForEach-Object { ([string]$_.path).Replace('\', '/') } | Sort-Object) -join ';'
    $entryReasonCode = [string]$_.reasonCode
    $entryKey = "{0}|{1}|{2}|{3}" -f $entryWorkspace, $entryWorkspacePath, $entryPblPaths, $entryReasonCode
    $entryKey -ne $newEntryKey
})

$entries += [pscustomobject]@{
    workspaceName = $workspaceRootName
    workspacePath = $normalizedWorkspacePath
    pbls = @($pblFacts)
    reasonCode = $ReasonCode
    reason = $Reason
    reviewedBy = $ReviewedBy
    reviewedAt = $ReviewedAt
}

$updated = [pscustomobject]@{
    schemaName = "pbbridge-pbl-binary-baselines/v2"
    entries = @($entries | Sort-Object workspaceName, workspacePath, reasonCode)
}

New-Item -ItemType Directory -Path (Split-Path -Parent $policyPath) -Force | Out-Null
$updated | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $policyPath -Encoding utf8

Write-Output "PBL Binary Baseline Policy"
Write-Output ("PolicyPath: {0}" -f $policyPath)
Write-Output ("WorkspaceName: {0}" -f $workspaceRootName)
Write-Output ("WorkspacePath: {0}" -f $(if ([string]::IsNullOrWhiteSpace($normalizedWorkspacePath)) { "<none>" } else { $normalizedWorkspacePath }))
Write-Output ("PblPaths: {0}" -f ($normalizedPblPaths -join ", "))
Write-Output ("ReasonCode: {0}" -f $ReasonCode)
