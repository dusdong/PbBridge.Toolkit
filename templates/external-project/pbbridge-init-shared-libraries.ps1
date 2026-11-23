#requires -PSEdition Core
#requires -Version 7.4

# PbBridge-TemplateVersion: 7.7.2
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
        ForEach-Object Name |
        Sort-Object { $_.Trim().ToLowerInvariant() } -Unique)
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

function ConvertTo-ProjectPath {
    param([string]$Root, [string]$FullPath)

    $relative = [System.IO.Path]::GetRelativePath($Root, $FullPath).Replace('\', '/')
    if ([System.IO.Path]::IsPathRooted($relative) -or $relative -eq '..' -or $relative.StartsWith('../')) {
        return $FullPath.Replace('\', '/')
    }
    return $relative
}

function Get-WorkspaceEvidenceDirectory {
    param([string]$Root, [string]$Name)

    $workspaceRoot = Get-WorkspaceRoot -Root $Root -Name $Name
    $registrationPath = Join-Path $workspaceRoot 'workspace.json'
    if (Test-Path -LiteralPath $registrationPath -PathType Leaf) {
        $registration = Read-JsonFile -Path $registrationPath
        $registeredManifest = [string](Get-JsonProperty -Object $registration -Name 'manifestPath')
        if (-not [string]::IsNullOrWhiteSpace($registeredManifest)) {
            $registeredFullPath = Resolve-FullPath -BasePath $Root -PathValue $registeredManifest
            $projectPath = ConvertTo-ProjectPath -Root $Root -FullPath $registeredFullPath
            $registeredDirectory = [System.IO.Path]::GetDirectoryName($registeredFullPath)
            if (-not [System.IO.Path]::IsPathRooted($projectPath) -and $registeredDirectory) {
                $canonicalManifest = Join-Path $registeredDirectory 'manifest.json'
                # 由平台的路径比较规则判断两个文件名是否等价。
                if ([System.IO.Path]::GetRelativePath($canonicalManifest, $registeredFullPath) -ceq '.') {
                    return $registeredDirectory
                }
            }
        }
    }

    return Join-Path $workspaceRoot 'artifacts\pbbridge'
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
$managedWorkspaceNames = @(Get-ManagedWorkspaceNames -Root $repoRoot)
$hasMultipleParentWorkspaces = $managedWorkspaceNames.Count -gt 1
$parentArtifactsFullPath = if (-not [string]::IsNullOrWhiteSpace($ParentArtifactsPath)) {
    Resolve-FullPath -BasePath $repoRoot -PathValue $ParentArtifactsPath
}
elseif (-not [string]::IsNullOrWhiteSpace($WorkspaceName)) {
    $normalizedName = $WorkspaceName.Trim().ToLowerInvariant()
    $registeredName = $managedWorkspaceNames | Where-Object { $_.Trim() -eq $normalizedName } | Select-Object -First 1
    Get-WorkspaceEvidenceDirectory -Root $repoRoot -Name ($registeredName ?? $normalizedName)
}
elseif (-not $hasMultipleParentWorkspaces) {
    $onlyWorkspace = if ($managedWorkspaceNames.Count -eq 1) { $managedWorkspaceNames[0] } else { 'default' }
    Get-WorkspaceEvidenceDirectory -Root $repoRoot -Name $onlyWorkspace
}
if ([string]::IsNullOrWhiteSpace($ResultJsonPath)) {
    $ResultJsonPath = Join-Path $repoRoot '.pbbridge\shared-libraries.init.json'
}
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $repoRoot '.pbbridge\shared-libraries.json'
}

$resultPath = Resolve-FullPath -BasePath $repoRoot -PathValue $ResultJsonPath
$configFullPath = Resolve-FullPath -BasePath $repoRoot -PathValue $ConfigPath
if ([System.IO.Path]::GetRelativePath($configFullPath, $resultPath) -ceq '.') {
    throw '初始化报告和正式配置必须使用不同路径，请分别指定 -ResultJsonPath 和 -ConfigPath。'
}
$manifestPath = if ($parentArtifactsFullPath) { Join-Path $parentArtifactsFullPath 'manifest.json' }
$manifest = if ($manifestPath -and (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { Read-JsonFile -Path $manifestPath }
$parentOutputPath = if (-not $hasMultipleParentWorkspaces) {
    ConvertTo-ProjectPath -Root $repoRoot -FullPath $parentArtifactsFullPath
}
$workspaceResults = if ($hasMultipleParentWorkspaces) {
    foreach ($name in $managedWorkspaceNames) {
        $workspaceId = $name.Trim().ToLowerInvariant()
        [pscustomobject]@{
            workspaceName = $workspaceId
            resultJsonPath = ".pbbridge/workspaces/$workspaceId/state/shared-library-writeback-check.json"
        }
    }
}
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
    $coveredByParent = if ($manifestPath) { Test-ManifestCoversPath -Manifest $manifest -RelativePath $path }
    $mode = if ($hasWorkspace) { 'self' } else { 'consumer' }
    $workspacePath = if (@($pbw).Count -gt 0) { $pbw[0].Name } elseif (@($pbt).Count -gt 0) { $pbt[0].Name } else { $null }
    $limitations = [System.Collections.Generic.List[string]]::new()
    $nextActions = [System.Collections.Generic.List[string]]::new()
    if (-not $manifestPath) {
        $limitations.Add('父项目有多个受管工作区，尚未选定并核对某一份父项目 manifest。') | Out-Null
        $nextActions.Add('如需核对父项目 manifest，请传入 -WorkspaceName 或 -ParentArtifactsPath。') | Out-Null
    }
    if (-not $hasWorkspace) {
        if ($coveredByParent) {
            $limitations.Add('未找到共享库独立 PBW/PBT；已按父项目 consumer evidence 草案处理。') | Out-Null
        }
        elseif ($manifestPath) {
            $limitations.Add('未找到共享库独立 PBW/PBT，父项目 manifest 也未覆盖该路径；仍按 consumer evidence 草案输出，需人工确认父项目 PBW/PBT 或 library-set 是否引用该共享库。') | Out-Null
        }
        else {
            $limitations.Add('未找到共享库独立 PBW/PBT，已生成 consumer evidence 草案。') | Out-Null
        }
        $nextActions.Add('确认父项目 PBW/PBT、.pbbridge/library-set.json 或 readonly-sync 参数包含该共享库后，再将草案复制为 .pbbridge/shared-libraries.json。') | Out-Null
        $nextActions.Add("建议 readonly-sync 排除已有源码事实源的共享库：-ExcludeLibrary '$path/*'。") | Out-Null
    }

    $sharedWorkspaceNames = @(Get-ManagedWorkspaceNames -Root $fullPath)
    $sharedOutputPath = if ($sharedWorkspaceNames.Count -gt 1) {
        $limitations.Add("共享库 $path 的受管工作区候选：$($sharedWorkspaceNames -join '、')。") | Out-Null
        if ($hasWorkspace) {
            $nextActions.Add("采用草案前，请为共享库 $path 填写所选工作区的 sharedOutputPath。") | Out-Null
        }
    }
    else {
        $sharedWorkspace = if ($sharedWorkspaceNames.Count -eq 1) { $sharedWorkspaceNames[0] } else { 'default' }
        $sharedArtifacts = Get-WorkspaceEvidenceDirectory -Root $fullPath -Name $sharedWorkspace
        ConvertTo-ProjectPath -Root $repoRoot -FullPath $sharedArtifacts
    }
    $libraryName = [System.IO.Path]::GetFileName($path.TrimEnd('/'))
    $entries.Add([pscustomobject]@{
        name = $libraryName
        path = $path
        evidenceMode = $mode
        parentOutputPath = $parentOutputPath
        sharedOutputPath = $sharedOutputPath
        resultJsonPath = if (-not $hasMultipleParentWorkspaces) { ".pbbridge/shared-library-writeback-check.$libraryName.json" }
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
            parentOutputPath = $_.parentOutputPath
            sharedOutputPath = $_.sharedOutputPath
            resultJsonPath = $_.resultJsonPath
            workspaceResults = $_.workspaceResults
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
    $librariesNeedingOutput = @($entries | Where-Object { $_.evidenceMode -eq 'self' -and -not $_.sharedOutputPath })
    if ($librariesNeedingOutput.Count -gt 0) {
        throw "请审查初始化草案并逐库填写 sharedOutputPath 后再采用：$($librariesNeedingOutput.path -join '、')。"
    }
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
