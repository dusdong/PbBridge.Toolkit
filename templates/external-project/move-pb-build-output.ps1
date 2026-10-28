#requires -PSEdition Core
#requires -Version 7.4

<#
# PbBridge-TemplateVersion: 7.6.0
.SYNOPSIS
移动 PowerBuilder 编译产物到仓库根目录 bin。

.DESCRIPTION
这是外部业务项目可复制的固定脚本。日常不需要传入路径参数：

  powershell -ExecutionPolicy Bypass -File .\scripts\move-pb-build-output.ps1

默认从仓库根目录和根目录下现有的 pb-* 依赖 PB 子模块直接子文件中选择 .pbd 与 .exe，
移动到仓库根目录 bin，并覆盖 bin 中已有的同名编译产物。
脚本默认不递归扫描子目录，避免误处理 toolkit runtime、历史发布目录或第三方工具。

.PARAMETER PassThru
输出结构化移动结果。

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\scripts\move-pb-build-output.ps1 -WhatIf

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\scripts\move-pb-build-output.ps1

.OUTPUTS
System.Management.Automation.PSCustomObject

.NOTES
该脚本只整理 .pbd 与 .exe 文件；PowerBuilder 库文件不属于构建产物整理范围。
固定排除 pbregexp_pb9.pbd，避免移动项目保留的老依赖。
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param(
    [Parameter()]
    [switch]$PassThru,
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
if ($Help.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "move-pb-build-output.ps1" -CliCommand ""; exit 0 }
if ($CliHelp.IsPresent) { Show-PbBridgeWrapperHelp -WrapperName "move-pb-build-output.ps1" -CliCommand ""; exit 0 }



$repoRoot = (Resolve-TemplateProjectRoot).TrimEnd('\')
$binPath = Join-Path $repoRoot "bin"
$dependencyModuleDirectories = @(Get-ChildItem -LiteralPath $repoRoot -Directory -Filter "pb-*" |
    Sort-Object -Property Name |
    Select-Object -ExpandProperty FullName)
$sourceDirectories = @($repoRoot) + $dependencyModuleDirectories
$excludedFileNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
[void]$excludedFileNames.Add("pbregexp_pb9.pbd")

$allowedExtensions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
[void]$allowedExtensions.Add(".pbd")
[void]$allowedExtensions.Add(".exe")

function New-BuildOutputResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath,

        [Parameter(Mandatory = $true)]
        [string]$Extension,

        [Parameter(Mandatory = $true)]
        [string]$Status
    )

    return [PSCustomObject]@{
        SourcePath = $SourcePath
        TargetPath = $TargetPath
        Extension  = $Extension
        Status     = $Status
    }
}

function Get-BuildOutputCandidate {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$SourceDirectories,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.HashSet[string]]$AllowedExtensions,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.HashSet[string]]$ExcludedFileNames
    )

    foreach ($sourceDirectory in $SourceDirectories) {
        $sourceFullPath = [System.IO.Path]::GetFullPath($sourceDirectory)
        if (-not (Test-Path -LiteralPath $sourceFullPath -PathType Container)) {
            Write-Verbose -Message "跳过不存在的构建产物目录：$sourceFullPath"
            continue
        }

        Get-ChildItem -LiteralPath $sourceFullPath -File |
            Where-Object {
                $AllowedExtensions.Contains($_.Extension) -and
                -not $ExcludedFileNames.Contains($_.Name)
            }
    }
}

$candidates = @(Get-BuildOutputCandidate `
        -SourceDirectories $sourceDirectories `
        -AllowedExtensions $allowedExtensions `
        -ExcludedFileNames $excludedFileNames |
    Sort-Object -Property FullName)

if ($candidates.Count -eq 0) {
    Write-Verbose -Message "未找到需要移动的 PowerBuilder 编译产物。"
    return
}

if (-not (Test-Path -LiteralPath $binPath -PathType Container)) {
    if ($PSCmdlet.ShouldProcess($binPath, "Create bin directory")) {
        New-Item -ItemType Directory -Path $binPath -Force | Out-Null
    }
}

foreach ($candidate in $candidates) {
    if (-not $allowedExtensions.Contains($candidate.Extension)) {
        continue
    }

    if ($excludedFileNames.Contains($candidate.Name)) {
        continue
    }

    $targetPath = Join-Path $binPath $candidate.Name
    if ($candidate.FullName.Equals($targetPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        continue
    }

    if ($PSCmdlet.ShouldProcess($candidate.FullName, "Move build output -> $targetPath")) {
        Move-Item -LiteralPath $candidate.FullName -Destination $targetPath -Force -ErrorAction Stop
        if ($PassThru.IsPresent) {
            New-BuildOutputResult `
                -SourcePath $candidate.FullName `
                -TargetPath $targetPath `
                -Extension $candidate.Extension `
                -Status "Moved"
        }
    }
}
