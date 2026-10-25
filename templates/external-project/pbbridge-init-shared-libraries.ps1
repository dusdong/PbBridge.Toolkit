#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.5.3
param(
    [string]$ProjectRoot = "",
    [string]$WorkspaceName = "",
    [string]$ParentArtifactsPath = "",
    [string]$ResultJsonPath = "",
    [string]$ConfigPath = "",
    [switch]$Apply,
    [switch]$Force,
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-init-shared-libraries.ps1" -CliCommand ""; exit 0 }
if ($CliHelp.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "pbbridge-init-shared-libraries.ps1" -CliCommand ""; exit 0 }

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

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$BasePath, [Parameter(Mandatory = $true)][string]$PathValue)

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $PathValue))
}

function Get-WorkspaceRoot {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Name)

    return Join-Path $Root (Join-Path '.pbbridge\workspaces' $Name)
}

function Get-ManagedWorkspaceNames {
    param([Parameter(Mandatory = $true)][string]$Root)

    $workspacesRoot = Join-Path $Root '.pbbridge\workspaces'
    if (-not (Test-Path -LiteralPath $workspacesRoot -PathType Container)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $workspacesRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'workspace.json') -PathType Leaf } |
        ForEach-Object { $_.Name.Trim().ToLowerInvariant() } |
        Sort-Object -Unique)
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

function Get-JsonProperty {
    param($Object, [Parameter(Mandatory = $true)][string]$Name, $DefaultValue = $null)

    if ($null -eq $Object) {
        return $DefaultValue
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

function ConvertTo-NormalizedPath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return ''
    }

    return ([string]$PathValue).Replace('\', '/').Trim('/')
}

function Get-GitmodulePaths {
    param([Parameter(Mandatory = $true)][string]$Root)

    $gitmodules = Join-Path $Root '.gitmodules'
    if (-not (Test-Path -LiteralPath $gitmodules -PathType Leaf)) {
        return @()
    }

    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($line in [System.IO.File]::ReadLines($gitmodules)) {
        $match = [regex]::Match($line, '^\s*path\s*=\s*(.+?)\s*$')
        if ($match.Success) {
            $paths.Add($match.Groups[1].Value.Replace('\', '/').Trim()) | Out-Null
        }
    }

    return @($paths)
}

function Get-CommonSharedLibraryPaths {
    param([Parameter(Mandatory = $true)][string]$Root)

    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($candidate in @('pb-libs', 'pb-langchao')) {
        $fullPath = Join-Path $Root $candidate
        if (Test-Path -LiteralPath $fullPath -PathType Container) {
            $paths.Add($candidate) | Out-Null
        }
    }

    return @($paths)
}

function Test-IsToolingPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $normalized = ConvertTo-NormalizedPath -PathValue $RelativePath
    if ($normalized.StartsWith('.pbbridge/', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    foreach ($segment in @('PbBridge.Toolkit', 'PB.Avalonia.Bridge', 'Pbidea', 'Toolkit')) {
        if ($normalized.Equals($segment, [System.StringComparison]::OrdinalIgnoreCase) -or
            $normalized.EndsWith('/' + $segment, [System.StringComparison]::OrdinalIgnoreCase) -or
            $normalized.StartsWith($segment + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Test-HasPowerBuilderFootprint {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $normalized = ConvertTo-NormalizedPath -PathValue $RelativePath
    if ($normalized -in @('pb-libs', 'pb-langchao')) {
        return $true
    }

    $fullPath = Resolve-FullPath -BasePath $Root -PathValue $RelativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Container)) {
        return $false
    }

    foreach ($pattern in @('*.pbw', '*.pbt', '*.pbl', '*.pbd')) {
        if (@(Get-ChildItem -LiteralPath $fullPath -Filter $pattern -File -ErrorAction SilentlyContinue | Select-Object -First 1).Count -gt 0) {
            return $true
        }
    }

    return $false
}

function Test-ManifestCoversPath {
    param($Manifest, [Parameter(Mandatory = $true)][string]$RelativePath)

    if ($null -eq $Manifest) {
        return $false
    }

    $root = ConvertTo-NormalizedPath -PathValue $RelativePath
    foreach ($library in @((Get-JsonProperty -Object $Manifest -Name 'libraries' -DefaultValue @()))) {
        foreach ($candidate in @(
            [string](Get-JsonProperty -Object $library -Name 'pblPath' -DefaultValue ''),
            [string](Get-JsonProperty -Object $library -Name 'sourceRoot' -DefaultValue ''),
            [string](Get-JsonProperty -Object $library -Name 'libraryFilePath' -DefaultValue '')
        )) {
            $normalized = ConvertTo-NormalizedPath -PathValue $candidate
            if ($normalized.Equals($root, [System.StringComparison]::OrdinalIgnoreCase) -or $normalized.StartsWith($root + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
    }

    return $false
}

$repoRoot = Resolve-ProjectRoot -ExplicitRoot $ProjectRoot
$workspaceRootName = if ([string]::IsNullOrWhiteSpace($WorkspaceName)) { 'default' } else { $WorkspaceName.Trim().ToLowerInvariant() }
if ([string]::IsNullOrWhiteSpace($ParentArtifactsPath)) {
    $ParentArtifactsPath = Join-Path (Get-WorkspaceRoot -Root $repoRoot -Name $workspaceRootName) 'artifacts\pbbridge'
}
if ([string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    $ResultJsonPath = Join-Path $repoRoot '.pbbridge\shared-libraries.init.json'
}
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $repoRoot '.pbbridge\shared-libraries.json'
}

$parentArtifactsFullPath = Resolve-FullPath -BasePath $repoRoot -PathValue $ParentArtifactsPath
$resultPath = Resolve-FullPath -BasePath $repoRoot -PathValue $ResultJsonPath
$configFullPath = Resolve-FullPath -BasePath $repoRoot -PathValue $ConfigPath
$manifestPath = Join-Path $parentArtifactsFullPath 'manifest.json'
$manifest = if (Test-Path -LiteralPath $manifestPath -PathType Leaf) { Read-JsonFile -Path $manifestPath } else { $null }
$managedWorkspaceNames = @(Get-ManagedWorkspaceNames -Root $repoRoot)
$entries = [System.Collections.Generic.List[object]]::new()

$candidatePaths = @(Get-GitmodulePaths -Root $repoRoot) + @(Get-CommonSharedLibraryPaths -Root $repoRoot) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Where-Object { -not (Test-IsToolingPath -RelativePath $_) } |
    Where-Object { Test-HasPowerBuilderFootprint -Root $repoRoot -RelativePath $_ } |
    Select-Object -Unique

foreach ($path in @($candidatePaths)) {
    $fullPath = Resolve-FullPath -BasePath $repoRoot -PathValue $path
    $pbw = @(Get-ChildItem -LiteralPath $fullPath -Filter '*.pbw' -File -ErrorAction SilentlyContinue | Select-Object -First 1)
    $pbt = @(Get-ChildItem -LiteralPath $fullPath -Filter '*.pbt' -File -ErrorAction SilentlyContinue | Select-Object -First 1)
    $hasWorkspace = @($pbw).Count -gt 0 -or @($pbt).Count -gt 0
    $coveredByParent = Test-ManifestCoversPath -Manifest $manifest -RelativePath $path
    $mode = if ($hasWorkspace) { 'self' } else { 'consumer' }
    $workspacePath = if (@($pbw).Count -gt 0) { $pbw[0].Name } elseif (@($pbt).Count -gt 0) { $pbt[0].Name } else { $null }
    $limitations = [System.Collections.Generic.List[string]]::new()
    $nextActions = [System.Collections.Generic.List[string]]::new()
    if (-not $hasWorkspace) {
        if ($coveredByParent) {
            $limitations.Add('未找到共享库独立 PBW/PBT；已按父项目 consumer evidence 草案处理。') | Out-Null
        }
        else {
            $limitations.Add('未找到共享库独立 PBW/PBT，父项目 manifest 也未覆盖该路径；仍按 consumer evidence 草案输出，需人工确认父项目 PBW/PBT 或 library-set 是否引用该共享库。') | Out-Null
        }
        $nextActions.Add('确认父项目 PBW/PBT、.pbbridge/library-set.json 或 readonly-sync 参数包含该共享库后，再将草案复制为 .pbbridge/shared-libraries.json。') | Out-Null
        $nextActions.Add("建议 readonly-sync 排除已有源码事实源的共享库：-ExcludeLibrary '$path/*'。") | Out-Null
    }

    $workspaceResults = if ($managedWorkspaceNames.Count -gt 1) {
        @($managedWorkspaceNames | ForEach-Object {
            [pscustomobject]@{
                workspaceName = $_
                resultJsonPath = ".pbbridge/workspaces/$_/state/shared-library-writeback-check.json"
            }
        })
    }
    else {
        @()
    }
    $entries.Add([pscustomobject]@{
        name = [System.IO.Path]::GetFileName($path.TrimEnd('/'))
        path = $path
        evidenceMode = $mode
        parentOutputPath = '.pbbridge/workspaces/default/artifacts/pbbridge'
        sharedOutputPath = "$path/.pbbridge/workspaces/default/artifacts/pbbridge"
        resultJsonPath = ".pbbridge/shared-library-writeback-check.$([System.IO.Path]::GetFileName($path.TrimEnd('/'))).json"
        workspaceResults = $workspaceResults
        workspacePath = $workspacePath
        sourceLayout = 'beside-pbl-src'
        scanScope = 'workspace-targets'
        includeLibrary = @()
        excludeLibrary = @()
        inferredFrom = [pscustomobject]@{
            hasWorkspace = $hasWorkspace
            parentManifestCovered = $coveredByParent
            manifestPath = $manifestPath
        }
        limitations = @($limitations)
        nextActions = @($nextActions)
    }) | Out-Null
}

$config = [pscustomobject]@{
    schemaName = 'pbbridge-shared-library-config'
    sharedLibraries = @($entries | ForEach-Object {
        [pscustomobject]@{
            name = $_.name
            path = $_.path
            evidenceMode = $_.evidenceMode
            parentOutputPath = if ($managedWorkspaceNames.Count -gt 1) { $null } else { $_.parentOutputPath }
            sharedOutputPath = $_.sharedOutputPath
            resultJsonPath = if ($managedWorkspaceNames.Count -gt 1) { $null } else { $_.resultJsonPath }
            workspaceResults = if ($managedWorkspaceNames.Count -gt 1) { $_.workspaceResults } else { $null }
            workspacePath = $_.workspacePath
            sourceLayout = $_.sourceLayout
            scanScope = $_.scanScope
            includeLibrary = $_.includeLibrary
            excludeLibrary = $_.excludeLibrary
        }
    })
}

$result = [pscustomobject]@{
    schemaName = 'pbbridge-shared-library-init'
    generatedAt = [DateTimeOffset]::Now.ToString('o')
    projectRoot = $repoRoot
    resultJsonPath = $resultPath
    configPath = $configFullPath
    applied = $false
    sharedLibraries = @($entries)
    proposedConfig = $config
    summaryText = "Generated shared library config proposal for $($entries.Count) submodule(s)."
}

New-Item -ItemType Directory -Path (Split-Path -Parent $resultPath) -Force | Out-Null
$result | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $resultPath -Encoding utf8

if ($Apply.IsPresent) {
    if ((Test-Path -LiteralPath $configFullPath -PathType Leaf) -and -not $Force.IsPresent) {
        throw "共享库配置已存在：$configFullPath。请审查后使用 -Force 覆盖。"
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $configFullPath) -Force | Out-Null
    $config | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $configFullPath -Encoding utf8
    $result.applied = $true
    $result | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $resultPath -Encoding utf8
}

Write-Output 'Shared Library Init Summary'
Write-Output ('SharedLibraries: {0}' -f $entries.Count)
Write-Output ('Applied: {0}' -f $result.applied)
Write-Output ('ResultJsonPath: {0}' -f $resultPath)
Write-Output ('ConfigPath: {0}' -f $configFullPath)
