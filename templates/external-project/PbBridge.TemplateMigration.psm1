#requires -PSEdition Core
#requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ProductVersion = '7.6.1'
$script:NormalizationProfile = 'powershell-text-v1'
$script:SupportedSourceProductVersions = @(
    '7.0.0'
    '7.0.1'
    '7.0.2'
    '7.1.0'
    '7.1.1'
    '7.2.0'
    '7.2.1'
    '7.2.2'
    '7.2.3'
    '7.3.0'
    '7.3.1'
    '7.3.2'
    '7.4.0'
    '7.4.2'
    '7.4.3'
    '7.4.4'
    '7.5.0'
    '7.5.1'
    '7.5.2'
    '7.5.3'
    $script:ProductVersion
) | Select-Object -Unique
$script:ApprovedMigrationBootstrapPatchHashes = @{
    'scripts/pbbridge-template-migrate.ps1' = @(
        '3f6915037db1c70fd64cffe9e9cf11c77fed8c54d68d8f3f741512ceb2397b65'
    )
}
$script:ApprovedMappings = [ordered]@{
    WorkspaceName = 'workspace.id'
    WorkspacePath = 'workspace.pbwPath'
    SourceLayout = 'workspace.sourceLayout'
    ScanScope = 'workspace.scanScope'
    IncludeLibrary = 'workspace.includeLibraries'
    ExcludeLibrary = 'workspace.excludeLibraries'
    VerifyPolicyMode = 'workspace.verifyPolicyMode'
}

function Test-PbBridgeSupportedSourceProductVersion {
    param([AllowEmptyString()][string]$ProductVersion)

    return $ProductVersion -in $script:SupportedSourceProductVersions
}

function Get-PbBridgeSupportedSourceProductVersionText {
    return (@($script:SupportedSourceProductVersions) -join ', ')
}

function Get-PbBridgeSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            return ([System.BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
        }
        finally {
            $sha.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-PbBridgeTextSha256 {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-PbBridgeTextIdentity {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $rawSha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $rawSha256 = ([System.BitConverter]::ToString($rawSha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $rawSha.Dispose()
    }
    $encodingName = $null
    $offset = 0
    $encoding = $null

    try {
        if ($bytes.Length -ge 4 -and
            $bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) {
            $encodingName = 'utf-32be-bom'
            $offset = 4
            $encoding = [System.Text.UTF32Encoding]::new($true, $false, $true)
        }
        elseif ($bytes.Length -ge 4 -and
            $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x00) {
            $encodingName = 'utf-32le-bom'
            $offset = 4
            $encoding = [System.Text.UTF32Encoding]::new($false, $false, $true)
        }
        elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $encodingName = 'utf-8-bom'
            $offset = 3
            $encoding = [System.Text.UTF8Encoding]::new($false, $true)
        }
        elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            $encodingName = 'utf-16le-bom'
            $offset = 2
            $encoding = [System.Text.UnicodeEncoding]::new($false, $false, $true)
        }
        elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
            $encodingName = 'utf-16be-bom'
            $offset = 2
            $encoding = [System.Text.UnicodeEncoding]::new($true, $false, $true)
        }
        else {
            $encodingName = 'utf-8'
            $encoding = [System.Text.UTF8Encoding]::new($false, $true)
        }

        $text = $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
        $normalized = $text.Replace("`r`n", "`n").Replace("`r", "`n")
        return [pscustomobject]@{
            rawSha256 = $rawSha256
            normalizedTextSha256 = Get-PbBridgeTextSha256 -Text $normalized
            normalizationProfile = $script:NormalizationProfile
            normalizationSupported = $true
            encoding = $encodingName
            reasonCode = $null
        }
    }
    catch [System.Text.DecoderFallbackException] {
        return [pscustomobject]@{
            rawSha256 = $rawSha256
            normalizedTextSha256 = $null
            normalizationProfile = $script:NormalizationProfile
            normalizationSupported = $false
            encoding = $encodingName
            reasonCode = 'normalization-unsupported'
        }
    }
}

function Test-PbBridgeJsonEquivalent {
    param(
        [AllowNull()]$Left,
        [AllowNull()]$Right
    )

    if ($null -eq $Left -or $null -eq $Right) { return $null -eq $Left -and $null -eq $Right }
    $leftJson = ConvertTo-PbBridgeCanonicalJson -Value $Left
    $rightJson = ConvertTo-PbBridgeCanonicalJson -Value $Right
    return $leftJson -ceq $rightJson
}

function Get-PbBridgeOrdinalSortedStrings {
    param([Parameter(Mandatory = $true)][string[]]$Value)

    $copy = [string[]]@($Value)
    [Array]::Sort($copy, [StringComparer]::Ordinal)
    return ,$copy
}

function Add-PbBridgeCanonicalJsonString {
    param(
        [Parameter(Mandatory = $true)][System.Text.StringBuilder]$Builder,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value
    )

    [void]$Builder.Append('"')
    for ($index = 0; $index -lt $Value.Length; $index++) {
        $current = $Value[$index]
        $code = [int]$current
        if ($code -eq 8) { [void]$Builder.Append('\b'); continue }
        if ($code -eq 9) { [void]$Builder.Append('\t'); continue }
        if ($code -eq 10) { [void]$Builder.Append('\n'); continue }
        if ($code -eq 12) { [void]$Builder.Append('\f'); continue }
        if ($code -eq 13) { [void]$Builder.Append('\r'); continue }
        if ($code -eq 34) { [void]$Builder.Append('\"'); continue }
        if ($code -eq 92) { [void]$Builder.Append('\\'); continue }
        if ($code -lt 32) {
            [void]$Builder.Append(('\u{0:x4}' -f $code))
            continue
        }
        if ([char]::IsHighSurrogate($current)) {
            if ($index + 1 -ge $Value.Length -or -not [char]::IsLowSurrogate($Value[$index + 1])) {
                throw 'governance-canonical-json-invalid-high-surrogate'
            }
            [void]$Builder.Append($current)
            $index++
            [void]$Builder.Append($Value[$index])
            continue
        }
        if ([char]::IsLowSurrogate($current)) {
            throw 'governance-canonical-json-invalid-low-surrogate'
        }
        [void]$Builder.Append($current)
    }
    [void]$Builder.Append('"')
}

function ConvertTo-PbBridgeCanonicalNumber {
    param([Parameter(Mandatory = $true)]$Value)

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ($Value -is [decimal]) {
        if ($Value -eq [decimal]::Zero) { return '0' }
        return $Value.ToString('G29', $culture)
    }
    if ($Value -is [double] -or $Value -is [single]) {
        $number = [double]$Value
        if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) {
            throw 'governance-canonical-json-non-finite-number'
        }
        if ($number -eq 0) { return '0' }
        $text = $number.ToString('R', $culture).Replace('E', 'e')
        if ($text -match '^(?<mantissa>.+)e(?<sign>[+-]?)(?<digits>[0-9]+)$') {
            $digits = $Matches.digits.TrimStart('0')
            if ([string]::IsNullOrEmpty($digits)) { $digits = '0' }
            $sign = if ($Matches.sign -eq '-') { '-' } else { '' }
            return ('{0}e{1}{2}' -f $Matches.mantissa, $sign, $digits)
        }
        return $text
    }
    if ($Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64] -or $Value -is [uint64]) {
        return ([System.IFormattable]$Value).ToString($null, $culture)
    }
    throw ('governance-canonical-json-unsupported-number: {0}' -f $Value.GetType().FullName)
}

function Add-PbBridgeCanonicalJsonValue {
    param(
        [Parameter(Mandatory = $true)][System.Text.StringBuilder]$Builder,
        [Parameter(Mandatory = $true)][AllowNull()]$Value
    )

    if ($null -eq $Value) {
        [void]$Builder.Append('null')
        return
    }
    if ($Value -is [bool]) {
        [void]$Builder.Append($(if ($Value) { 'true' } else { 'false' }))
        return
    }
    if ($Value -is [string] -or $Value -is [char]) {
        Add-PbBridgeCanonicalJsonString -Builder $Builder -Value ([string]$Value)
        return
    }
    if ($Value -is [decimal] -or $Value -is [double] -or $Value -is [single] -or
        $Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64] -or $Value -is [uint64]) {
        [void]$Builder.Append((ConvertTo-PbBridgeCanonicalNumber -Value $Value))
        return
    }
    if ($Value -is [System.Collections.IDictionary]) {
        [void]$Builder.Append('{')
        $keys = Get-PbBridgeOrdinalSortedStrings -Value ([string[]]@($Value.Keys | ForEach-Object { [string]$_ }))
        $first = $true
        foreach ($key in $keys) {
            if (-not $first) { [void]$Builder.Append(',') }
            $first = $false
            Add-PbBridgeCanonicalJsonString -Builder $Builder -Value $key
            [void]$Builder.Append(':')
            Add-PbBridgeCanonicalJsonValue -Builder $Builder -Value $Value[$key]
        }
        [void]$Builder.Append('}')
        return
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        [void]$Builder.Append('[')
        $first = $true
        foreach ($item in $Value) {
            if (-not $first) { [void]$Builder.Append(',') }
            $first = $false
            Add-PbBridgeCanonicalJsonValue -Builder $Builder -Value $item
        }
        [void]$Builder.Append(']')
        return
    }

    $propertyMap = @{}
    foreach ($property in @($Value.PSObject.Properties | Where-Object MemberType -in @('NoteProperty', 'Property'))) {
        $propertyMap[[string]$property.Name] = $property.Value
    }
    if ($propertyMap.Count -eq 0) {
        throw ('governance-canonical-json-unsupported-value: {0}' -f $Value.GetType().FullName)
    }
    Add-PbBridgeCanonicalJsonValue -Builder $Builder -Value $propertyMap
}

function ConvertTo-PbBridgeCanonicalJson {
    param([Parameter(Mandatory = $true)][AllowNull()]$Value)

    $builder = [System.Text.StringBuilder]::new()
    Add-PbBridgeCanonicalJsonValue -Builder $builder -Value $Value
    return $builder.ToString()
}

function Get-PbBridgeManagedFileDifference {
    param(
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$TemplatePath
    )

    $targetLines = [System.IO.File]::ReadAllLines($TargetPath)
    $templateLines = [System.IO.File]::ReadAllLines($TemplatePath)
    $limit = [Math]::Min($targetLines.Length, $templateLines.Length)
    $firstDifference = $null
    for ($index = 0; $index -lt $limit; $index++) {
        if ($targetLines[$index] -cne $templateLines[$index]) {
            $firstDifference = $index + 1
            break
        }
    }
    if ($null -eq $firstDifference -and $targetLines.Length -ne $templateLines.Length) {
        $firstDifference = $limit + 1
    }

    $targetParse = Get-PbBridgePowerShellAst -Path $TargetPath
    $templateParse = Get-PbBridgePowerShellAst -Path $TemplatePath
    $targetParameters = @($targetParse.ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.ParameterAst] }, $true) |
        ForEach-Object { $_.Name.VariablePath.UserPath } | Sort-Object -Unique)
    $templateParameters = @($templateParse.ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.ParameterAst] }, $true) |
        ForEach-Object { $_.Name.VariablePath.UserPath } | Sort-Object -Unique)

    return [ordered]@{
        firstDifferingLine = $firstDifference
        targetLineCount = $targetLines.Length
        templateLineCount = $templateLines.Length
        addedParameters = @($targetParameters | Where-Object { $_ -notin $templateParameters })
        removedParameters = @($templateParameters | Where-Object { $_ -notin $targetParameters })
        targetSha256 = Get-PbBridgeSha256 -Path $TargetPath
        templateSha256 = Get-PbBridgeSha256 -Path $TemplatePath
    }
}

function Resolve-PbBridgeManagedFileClassification {
    param(
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$TemplatePath,
        [Parameter(Mandatory = $true)][string]$TargetRelativePath,
        [AllowNull()]$ProvenanceRegistry
    )

    $templateIdentity = Get-PbBridgeTextIdentity -Path $TemplatePath
    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        return [pscustomobject]@{
            classification = 'unmanaged'
            targetExists = $false
            targetSha256 = $null
            targetRawSha256 = $null
            targetNormalizedTextSha256 = $null
            templateSha256 = $templateIdentity.rawSha256
            templateRawSha256 = $templateIdentity.rawSha256
            templateNormalizedTextSha256 = $templateIdentity.normalizedTextSha256
            normalizationProfile = $script:NormalizationProfile
            normalizationSupported = $true
            normalizationReasonCode = $null
            matchedTemplateVersion = $null
            difference = $null
        }
    }

    $targetIdentity = Get-PbBridgeTextIdentity -Path $TargetPath
    if ($targetIdentity.rawSha256 -eq $templateIdentity.rawSha256) {
        return [pscustomobject]@{
            classification = 'managed-current-exact'
            targetExists = $true
            targetSha256 = $targetIdentity.rawSha256
            targetRawSha256 = $targetIdentity.rawSha256
            targetNormalizedTextSha256 = $targetIdentity.normalizedTextSha256
            templateSha256 = $templateIdentity.rawSha256
            templateRawSha256 = $templateIdentity.rawSha256
            templateNormalizedTextSha256 = $templateIdentity.normalizedTextSha256
            normalizationProfile = $script:NormalizationProfile
            normalizationSupported = $targetIdentity.normalizationSupported
            normalizationReasonCode = $targetIdentity.reasonCode
            matchedTemplateVersion = $script:ProductVersion
            difference = $null
        }
    }

    $knownForPath = @()
    if ($null -ne $ProvenanceRegistry) {
        $knownForPath = @($ProvenanceRegistry.files | Where-Object {
            [string]$_.targetPath -eq $TargetRelativePath
        })
    }
    $approvedPatchHashes = @($script:ApprovedMigrationBootstrapPatchHashes[$TargetRelativePath])
    if ($targetIdentity.rawSha256 -in $approvedPatchHashes) {
        return [pscustomobject]@{
            classification = 'managed-known-exact'
            targetExists = $true
            targetSha256 = $targetIdentity.rawSha256
            targetRawSha256 = $targetIdentity.rawSha256
            targetNormalizedTextSha256 = $targetIdentity.normalizedTextSha256
            templateSha256 = $templateIdentity.rawSha256
            templateRawSha256 = $templateIdentity.rawSha256
            templateNormalizedTextSha256 = $templateIdentity.normalizedTextSha256
            normalizationProfile = $script:NormalizationProfile
            normalizationSupported = $targetIdentity.normalizationSupported
            normalizationReasonCode = $targetIdentity.reasonCode
            matchedTemplateVersion = '7.2.2'
            difference = Get-PbBridgeManagedFileDifference -TargetPath $TargetPath -TemplatePath $TemplatePath
        }
    }
    $knownExact = @($knownForPath | Where-Object {
        $raw = if ($_.PSObject.Properties.Name -contains 'rawSha256') { [string]$_.rawSha256 } else { [string]$_.sha256 }
        -not [string]::IsNullOrWhiteSpace($raw) -and $raw -eq $targetIdentity.rawSha256
    })
    if ($knownExact.Count -gt 0) {
        return [pscustomobject]@{
            classification = 'managed-known-exact'
            targetExists = $true
            targetSha256 = $targetIdentity.rawSha256
            targetRawSha256 = $targetIdentity.rawSha256
            targetNormalizedTextSha256 = $targetIdentity.normalizedTextSha256
            templateSha256 = $templateIdentity.rawSha256
            templateRawSha256 = $templateIdentity.rawSha256
            templateNormalizedTextSha256 = $templateIdentity.normalizedTextSha256
            normalizationProfile = $script:NormalizationProfile
            normalizationSupported = $targetIdentity.normalizationSupported
            normalizationReasonCode = $targetIdentity.reasonCode
            matchedTemplateVersion = [string]$knownExact[0].templateVersion
            difference = Get-PbBridgeManagedFileDifference -TargetPath $TargetPath -TemplatePath $TemplatePath
        }
    }

    $knownNormalized = @()
    if ($targetIdentity.normalizationSupported) {
        $knownNormalized = @($knownForPath | Where-Object {
            $_.PSObject.Properties.Name -contains 'normalizedTextSha256' -and
            -not [string]::IsNullOrWhiteSpace([string]$_.normalizedTextSha256) -and
            [string]$_.normalizationProfile -eq $script:NormalizationProfile -and
            [string]$_.normalizedTextSha256 -eq $targetIdentity.normalizedTextSha256
        })
    }
    if ($knownNormalized.Count -gt 0 -or
        ($targetIdentity.normalizationSupported -and
            $targetIdentity.normalizedTextSha256 -eq $templateIdentity.normalizedTextSha256)) {
        $matchedVersion = if ($knownNormalized.Count -gt 0) { [string]$knownNormalized[0].templateVersion } else { $script:ProductVersion }
        return [pscustomobject]@{
            classification = 'managed-known-format-variant'
            targetExists = $true
            targetSha256 = $targetIdentity.rawSha256
            targetRawSha256 = $targetIdentity.rawSha256
            targetNormalizedTextSha256 = $targetIdentity.normalizedTextSha256
            templateSha256 = $templateIdentity.rawSha256
            templateRawSha256 = $templateIdentity.rawSha256
            templateNormalizedTextSha256 = $templateIdentity.normalizedTextSha256
            normalizationProfile = $script:NormalizationProfile
            normalizationSupported = $true
            normalizationReasonCode = $null
            matchedTemplateVersion = $matchedVersion
            difference = Get-PbBridgeManagedFileDifference -TargetPath $TargetPath -TemplatePath $TemplatePath
        }
    }

    return [pscustomobject]@{
        classification = if ($knownForPath.Count -gt 0) { 'managed-modified' } else { 'unmanaged' }
        targetExists = $true
        targetSha256 = $targetIdentity.rawSha256
        targetRawSha256 = $targetIdentity.rawSha256
        targetNormalizedTextSha256 = $targetIdentity.normalizedTextSha256
        templateSha256 = $templateIdentity.rawSha256
        templateRawSha256 = $templateIdentity.rawSha256
        templateNormalizedTextSha256 = $templateIdentity.normalizedTextSha256
        normalizationProfile = $script:NormalizationProfile
        normalizationSupported = $targetIdentity.normalizationSupported
        normalizationReasonCode = $targetIdentity.reasonCode
        matchedTemplateVersion = $null
        difference = Get-PbBridgeManagedFileDifference -TargetPath $TargetPath -TemplatePath $TemplatePath
    }
}

function Test-PbBridgeMeaningfulOverride {
    param([AllowNull()]$Value)

    if ($null -eq $Value) { return $false }
    if ($Value -is [string]) { return -not [string]::IsNullOrWhiteSpace($Value) }
    return $true
}

function New-PbBridgeWorkspaceConfiguration {
    param(
        [Parameter(Mandatory = $true)][string]$TemplateRoot,
        [Parameter(Mandatory = $true)][string]$WorkspaceId,
        [Parameter(Mandatory = $true)][string]$PbwPath
    )

    $templatePath = Join-Path $TemplateRoot 'pbbridge-workspace.example.json'
    if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
        throw "workspace-config-template-not-found: $templatePath"
    }

    $json = [System.IO.File]::ReadAllText($templatePath, [System.Text.Encoding]::UTF8)
    $json = $json.Replace('<workspace-id>', $WorkspaceId).Replace('<repo-relative-pbw-path>', $PbwPath)
    $template = $json | ConvertFrom-Json
    return [ordered]@{
        schemaName = [string]$template.schemaName
        schemaVersion = [int]$template.schemaVersion
        productVersion = $script:ProductVersion
        id = $WorkspaceId
        pbwPath = $PbwPath
        stateRoot = [string]$template.stateRoot
        manifestPath = [string]$template.manifestPath
        artifactRoot = [string]$template.artifactRoot
        resultRoot = [string]$template.resultRoot
        cacheRoot = [string]$template.cacheRoot
        policyPath = [string]$template.policyPath
        lockRoot = [string]$template.lockRoot
        recoveryRoot = [string]$template.recoveryRoot
        sourceLayout = [string]$template.sourceLayout
        scanScope = [string]$template.scanScope
        includeLibraries = @($template.includeLibraries)
        excludeLibraries = @($template.excludeLibraries)
        verifyPolicyMode = [string]$template.verifyPolicyMode
        resultRetentionDays = [int]$template.resultRetentionDays
    }
}

function Merge-PbBridgeWorkspaceConfiguration {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Configuration,
        [AllowNull()]$ExistingConfiguration,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Overrides,
        [switch]$PbwPathWasExplicit
    )

    foreach ($entry in @{
        'sourceLayout' = 'workspace.sourceLayout'
        'scanScope' = 'workspace.scanScope'
        'includeLibraries' = 'workspace.includeLibraries'
        'excludeLibraries' = 'workspace.excludeLibraries'
        'verifyPolicyMode' = 'workspace.verifyPolicyMode'
    }.GetEnumerator()) {
        if ($Overrides.Contains($entry.Value) -and (Test-PbBridgeMeaningfulOverride -Value $Overrides[$entry.Value])) {
            $Configuration[$entry.Key] = $Overrides[$entry.Value]
        }
    }

    if ($null -eq $ExistingConfiguration) { return }
    foreach ($propertyName in @(
        'pbwPath', 'stateRoot', 'manifestPath', 'artifactRoot', 'resultRoot', 'cacheRoot',
        'policyPath', 'lockRoot', 'recoveryRoot', 'sourceLayout', 'scanScope',
        'includeLibraries', 'excludeLibraries', 'verifyPolicyMode', 'resultRetentionDays')) {
        if ($propertyName -eq 'pbwPath' -and $PbwPathWasExplicit) { continue }
        $property = $ExistingConfiguration.PSObject.Properties[$propertyName]
        if ($null -ne $property -and (Test-PbBridgeMeaningfulOverride -Value $property.Value)) {
            $Configuration[$propertyName] = $property.Value
        }
    }
}

function Resolve-PbBridgePathInsideRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ReasonCode
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    $prefix = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    if (-not $pathFull.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -and
        -not $pathFull.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$ReasonCode`: $pathFull"
    }

    return $pathFull
}

function Get-PbBridgePowerShellAst {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    try {
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $content = [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
        }
        elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            $content = [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
        }
        elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
            $content = [System.Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2)
        }
        else {
            $content = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes)
        }
    }
    catch [System.Text.DecoderFallbackException] {
        $content = [System.Text.Encoding]::Default.GetString($bytes)
    }

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, $Path, [ref]$tokens, [ref]$errors)
    [pscustomobject]@{
        ast = $ast
        errors = @($errors | ForEach-Object {
            [pscustomobject]@{
                message = $_.Message
                line = $_.Extent.StartLineNumber
                column = $_.Extent.StartColumnNumber
                text = $_.Extent.Text
            }
        })
    }
}

function Get-PbBridgeStaticAstValue {
    param([Parameter(Mandatory = $true)][System.Management.Automation.Language.Ast]$Expression)

    if ($Expression -is [System.Management.Automation.Language.VariableExpressionAst]) {
        $name = $Expression.VariablePath.UserPath
        if ($name -eq 'null') { return [pscustomobject]@{ success = $true; value = $null; reasonCode = $null } }
        if ($name -eq 'true') { return [pscustomobject]@{ success = $true; value = $true; reasonCode = $null } }
        if ($name -eq 'false') { return [pscustomobject]@{ success = $true; value = $false; reasonCode = $null } }
    }

    $unsafeNodes = @($Expression.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -or
        $node -is [System.Management.Automation.Language.ScriptBlockExpressionAst] -or
        $node -is [System.Management.Automation.Language.MemberExpressionAst] -or
        $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -or
        $node -is [System.Management.Automation.Language.BinaryExpressionAst] -or
        $node -is [System.Management.Automation.Language.HashtableAst] -or
        ($node -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $node.VariablePath.UserPath -notin @('null', 'true', 'false'))
    }, $true))
    if ($unsafeNodes.Count -gt 0) {
        return [pscustomobject]@{ success = $false; value = $null; reasonCode = 'dynamic-default-expression' }
    }

    try {
        $value = $Expression.SafeGetValue()
    }
    catch {
        return [pscustomobject]@{ success = $false; value = $null; reasonCode = 'static-value-not-provable' }
    }

    $values = if ($value -is [System.Array]) { @($value) } else { @($value) }
    foreach ($item in $values) {
        if ($null -ne $item -and
            $item -isnot [string] -and
            $item -isnot [bool] -and
            $item -isnot [byte] -and
            $item -isnot [int16] -and
            $item -isnot [int32] -and
            $item -isnot [int64] -and
            $item -isnot [decimal] -and
            $item -isnot [double]) {
            return [pscustomobject]@{ success = $false; value = $null; reasonCode = 'unsupported-static-value-type' }
        }
    }

    return [pscustomobject]@{ success = $true; value = $value; reasonCode = $null }
}

function Get-PbBridgeAstCommandNames {
    param([Parameter(Mandatory = $true)][System.Management.Automation.Language.Ast]$Ast)

    return @($Ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) |
        ForEach-Object { $_.GetCommandName() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique)
}

function Get-PbBridgeWrapperScan {
    param(
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$TemplatePath,
        [Parameter(Mandatory = $true)][string]$TargetRelativePath
    )

    $manual = New-Object System.Collections.Generic.List[object]
    $mappings = New-Object System.Collections.Generic.List[object]
    $targetParse = Get-PbBridgePowerShellAst -Path $TargetPath
    if ($targetParse.errors.Count -gt 0) {
        foreach ($error in $targetParse.errors) {
            $manual.Add([pscustomobject]@{
                file = $TargetRelativePath
                code = 'legacy-wrapper-syntax-invalid'
                message = $error.message
                line = $error.line
                column = $error.column
            })
        }
        return [pscustomobject]@{ mappings = $mappings.ToArray(); manual = $manual.ToArray() }
    }

    $templateParse = Get-PbBridgePowerShellAst -Path $TemplatePath
    if ($templateParse.errors.Count -gt 0) {
        foreach ($error in $templateParse.errors) {
            $manual.Add([pscustomobject]@{
                file = $TargetRelativePath
                code = 'candidate-template-syntax-invalid'
                message = $error.message
                line = $error.line
                column = $error.column
            })
        }
        return [pscustomobject]@{ mappings = $mappings.ToArray(); manual = $manual.ToArray() }
    }

    $targetFunctions = @($targetParse.ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
        ForEach-Object { $_.Name } | Sort-Object -Unique)
    $templateFunctions = @($templateParse.ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
        ForEach-Object { $_.Name } | Sort-Object -Unique)
    foreach ($name in @($targetFunctions | Where-Object { $_ -notin $templateFunctions })) {
        $manual.Add([pscustomobject]@{
            file = $TargetRelativePath
            code = 'custom-function-detected'
            message = "受管 wrapper 包含模板外函数：$name。请迁入受支持 hook 或独立非受管脚本。"
            line = $null
            column = $null
        })
    }

    $templateCommands = @(Get-PbBridgeAstCommandNames -Ast $templateParse.ast)
    foreach ($name in @(Get-PbBridgeAstCommandNames -Ast $targetParse.ast | Where-Object { $_ -notin $templateCommands })) {
        $manual.Add([pscustomobject]@{
            file = $TargetRelativePath
            code = 'custom-execution-logic-detected'
            message = "受管 wrapper 包含模板外命令：$name。请迁入受支持 hook 或独立非受管脚本。"
            line = $null
            column = $null
        })
    }

    $parameters = @($targetParse.ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.ParameterAst] }, $true))
    foreach ($parameter in $parameters) {
        $name = $parameter.Name.VariablePath.UserPath
        if (-not $script:ApprovedMappings.Contains($name) -or $null -eq $parameter.DefaultValue) {
            continue
        }

        $extracted = Get-PbBridgeStaticAstValue -Expression $parameter.DefaultValue
        if (-not $extracted.success) {
            $manual.Add([pscustomobject]@{
                file = $TargetRelativePath
                code = $extracted.reasonCode
                message = "参数 $name 的默认值无法静态迁移；迁移器不会执行或复制该表达式。"
                line = $parameter.Extent.StartLineNumber
                column = $parameter.Extent.StartColumnNumber
            })
            continue
        }

        $mappings.Add([pscustomobject]@{
            file = $TargetRelativePath
            parameter = $name
            configPath = $script:ApprovedMappings[$name]
            value = $extracted.value
            sourceText = $parameter.DefaultValue.Extent.Text
        })
    }

    return [pscustomobject]@{ mappings = $mappings.ToArray(); manual = $manual.ToArray() }
}

function Test-PbBridgeCandidateTree {
    param(
        [Parameter(Mandatory = $true)][string]$StagingRoot,
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$WorkspaceId,
        [Parameter(Mandatory = $true)][string]$TemplateManifestPath,
        [Parameter(Mandatory = $true)][string]$ToolkitRoot,
        [string[]]$PreservedRelativePath = @()
    )

    $issues = New-Object System.Collections.Generic.List[object]
    $preservedPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($relativePath in @($PreservedRelativePath)) {
        [void]$preservedPaths.Add(([string]$relativePath).Replace('\', '/'))
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $StagingRoot -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') })) {
        $relativePath = $file.FullName.Substring($StagingRoot.TrimEnd('\', '/').Length).TrimStart('\', '/').Replace('\', '/')
        if ($preservedPaths.Contains($relativePath)) { continue }
        $parsed = Get-PbBridgePowerShellAst -Path $file.FullName
        foreach ($error in $parsed.errors) {
            $issues.Add([pscustomobject]@{
                code = 'candidate-syntax-invalid'
                path = $file.FullName
                line = $error.line
                column = $error.column
                message = $error.message
            })
        }
    }

    try {
        $templateManifest = Get-Content -LiteralPath $TemplateManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $bootstrapFiles = @($templateManifest.managedFiles | Where-Object { $_.PSObject.Properties.Name -contains 'assetGroup' -and [string]$_.assetGroup -eq 'migration-bootstrap' })
        if ($bootstrapFiles.Count -ne 2) {
            $issues.Add([pscustomobject]@{ code = 'template-migration-bootstrap-pair-incomplete'; path = $TemplateManifestPath; line = $null; column = $null; message = 'migration-bootstrap manifest 必须且只能声明入口与模块两个成员。' })
        }
        else {
            $bootstrapCandidates = @($bootstrapFiles | ForEach-Object {
                $stagingPath = Join-Path $StagingRoot ([string]$_.targetPath)
                $installedPath = Join-Path $ProjectRoot ([string]$_.targetPath)
                $candidatePath = if (Test-Path -LiteralPath $stagingPath -PathType Leaf) { $stagingPath } else { $installedPath }
                [pscustomobject]@{
                    Manifest = $_
                    Path = $candidatePath
                    Exists = (Test-Path -LiteralPath $candidatePath -PathType Leaf)
                    Source = if ([string]::Equals($candidatePath, $stagingPath, [StringComparison]::OrdinalIgnoreCase)) { 'staging' } else { 'installed-current' }
                }
            })
            if (@($bootstrapCandidates | Where-Object { -not $_.Exists }).Count -gt 0) {
                $issues.Add([pscustomobject]@{ code = 'template-migration-bootstrap-pair-incomplete'; path = $StagingRoot; line = $null; column = $null; message = 'migration-bootstrap 候选缺少入口或模块，禁止半安装。' })
            }
            else {
                foreach ($candidate in $bootstrapCandidates) {
                    $canonicalPath = Join-Path (Split-Path -Parent $TemplateManifestPath) ([string]$candidate.Manifest.templatePath)
                    if ((Get-PbBridgeSha256 -Path $candidate.Path) -ne (Get-PbBridgeSha256 -Path $canonicalPath)) {
                        $issues.Add([pscustomobject]@{ code = 'template-migration-bootstrap-pair-version-mismatch'; path = $candidate.Path; line = $null; column = $null; message = 'migration-bootstrap 候选哈希与当前 canonical 模板不一致。' })
                    }
                }
                $entryPath = [string](@($bootstrapCandidates | Where-Object { [string]$_.Manifest.targetPath -eq 'scripts/pbbridge-template-migrate.ps1' })[0].Path)
                $modulePath = [string](@($bootstrapCandidates | Where-Object { [string]$_.Manifest.targetPath -eq 'scripts/PbBridge.TemplateMigration.psm1' })[0].Path)
                $entryText = Get-Content -LiteralPath $entryPath -Raw -Encoding UTF8
                $moduleText = Get-Content -LiteralPath $modulePath -Raw -Encoding UTF8
                $entryVersion = if ($entryText -match "(?m)ProductVersion\s*=\s*'([^']+)'") { $Matches[1] } else { $null }
                $moduleVersion = if ($moduleText -match "(?m)ProductVersion\s*=\s*'([^']+)'") { $Matches[1] } else { $null }
                if ($entryVersion -ne $script:ProductVersion -or $moduleVersion -ne $script:ProductVersion -or $entryVersion -ne $moduleVersion -or
                    $entryText -notmatch 'Join-Path\s+\$PSScriptRoot\s+''PbBridge\.TemplateMigration\.psm1''') {
                    $issues.Add([pscustomobject]@{ code = 'template-migration-bootstrap-pair-version-mismatch'; path = $entryPath; line = $null; column = $null; message = 'migration-bootstrap 入口与模块的版本或同目录加载握手不一致。' })
                }
            }
        }
    }
    catch {
        $issues.Add([pscustomobject]@{ code = 'template-migration-bootstrap-pair-incomplete'; path = $TemplateManifestPath; line = $null; column = $null; message = $_.Exception.Message })
    }

    $projectConfigPath = Join-Path $StagingRoot '.pbbridge\project.json'
    $workspaceConfigPath = Join-Path $StagingRoot (".pbbridge\workspaces\{0}\workspace.json" -f $WorkspaceId)
    try {
        $projectConfig = Get-Content -LiteralPath $projectConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($projectConfig.schemaName -ne 'pbbridge-project-config' -or
            $projectConfig.schemaVersion -ne 7 -or
            $projectConfig.productVersion -ne $script:ProductVersion) {
            $issues.Add([pscustomobject]@{ code = 'project-config-contract-invalid'; path = $projectConfigPath; line = $null; column = $null; message = 'project.json 必须使用 V7 schema。' })
        }
    }
    catch {
        $issues.Add([pscustomobject]@{ code = 'project-config-json-invalid'; path = $projectConfigPath; line = $null; column = $null; message = $_.Exception.Message })
    }

    try {
        $workspaceConfig = Get-Content -LiteralPath $workspaceConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $propertyNames = @($workspaceConfig.PSObject.Properties.Name)
        $requiredProperties = @(
            'schemaName', 'schemaVersion', 'productVersion', 'id', 'pbwPath', 'stateRoot', 'manifestPath',
            'artifactRoot', 'resultRoot', 'cacheRoot', 'policyPath', 'lockRoot', 'recoveryRoot',
            'sourceLayout', 'scanScope', 'includeLibraries', 'excludeLibraries', 'verifyPolicyMode', 'resultRetentionDays')
        foreach ($propertyName in $requiredProperties) {
            if ($propertyNames -notcontains $propertyName) {
                $issues.Add([pscustomobject]@{ code = 'workspace-config-required-field-missing'; fieldPath = "workspace.$propertyName"; path = $workspaceConfigPath; line = $null; column = $null; message = "workspace.json 缺少必需字段：$propertyName。" })
            }
        }

        if ($workspaceConfig.schemaName -ne 'pbbridge-workspace-config' -or
            $workspaceConfig.schemaVersion -ne 7 -or
            $workspaceConfig.productVersion -ne $script:ProductVersion -or
            $workspaceConfig.id -ne $WorkspaceId -or
            [string]::IsNullOrWhiteSpace([string]$workspaceConfig.pbwPath) -or
            [System.IO.Path]::IsPathRooted([string]$workspaceConfig.pbwPath) -or
            ([string]$workspaceConfig.pbwPath).Split(@('\', '/')) -contains '..') {
            $issues.Add([pscustomobject]@{ code = 'workspace-config-contract-invalid'; fieldPath = 'workspace'; path = $workspaceConfigPath; line = $null; column = $null; message = 'workspace.json 的 V7 schema、id 或 pbwPath 无效。' })
        }

        foreach ($fieldName in @('manifestPath', 'sourceLayout', 'scanScope', 'verifyPolicyMode')) {
            if ($propertyNames -contains $fieldName -and [string]::IsNullOrWhiteSpace([string]$workspaceConfig.$fieldName)) {
                $issues.Add([pscustomobject]@{ code = 'workspace-config-semantic-field-empty'; fieldPath = "workspace.$fieldName"; path = $workspaceConfigPath; line = $null; column = $null; message = "workspace.json 字段不能为空白：$fieldName。" })
            }
        }
        foreach ($fieldName in @('stateRoot', 'manifestPath', 'artifactRoot', 'resultRoot', 'cacheRoot', 'policyPath', 'lockRoot', 'recoveryRoot')) {
            if ($propertyNames -contains $fieldName) {
                $pathValue = [string]$workspaceConfig.$fieldName
                if ([string]::IsNullOrWhiteSpace($pathValue) -or [System.IO.Path]::IsPathRooted($pathValue) -or $pathValue.Split(@('\', '/')) -contains '..') {
                    $issues.Add([pscustomobject]@{ code = 'workspace-config-path-invalid'; fieldPath = "workspace.$fieldName"; path = $workspaceConfigPath; line = $null; column = $null; message = "workspace.json 路径字段必须是 repo 内相对路径：$fieldName。" })
                }
            }
        }
        if ($propertyNames -contains 'sourceLayout' -and [string]$workspaceConfig.sourceLayout -notin @('beside-pbl-src')) {
            $issues.Add([pscustomobject]@{ code = 'workspace-config-source-layout-invalid'; fieldPath = 'workspace.sourceLayout'; path = $workspaceConfigPath; line = $null; column = $null; message = 'sourceLayout 无效。' })
        }
        if ($propertyNames -contains 'scanScope' -and [string]$workspaceConfig.scanScope -notin @('workspace-targets', 'all-targets', 'all-pbl')) {
            $issues.Add([pscustomobject]@{ code = 'workspace-config-scan-scope-invalid'; fieldPath = 'workspace.scanScope'; path = $workspaceConfigPath; line = $null; column = $null; message = 'scanScope 无效。' })
        }
        if ($propertyNames -contains 'verifyPolicyMode' -and [string]$workspaceConfig.verifyPolicyMode -notin @('Disabled', 'UseExisting', 'RequireExisting')) {
            $issues.Add([pscustomobject]@{ code = 'workspace-config-verify-policy-invalid'; fieldPath = 'workspace.verifyPolicyMode'; path = $workspaceConfigPath; line = $null; column = $null; message = 'verifyPolicyMode 无效。' })
        }
        if ($propertyNames -contains 'includeLibraries' -and $null -eq $workspaceConfig.includeLibraries) {
            $issues.Add([pscustomobject]@{ code = 'workspace-config-library-filter-null'; fieldPath = 'workspace.includeLibraries'; path = $workspaceConfigPath; line = $null; column = $null; message = 'includeLibraries 不能为 null。' })
        }
        if ($propertyNames -contains 'excludeLibraries' -and $null -eq $workspaceConfig.excludeLibraries) {
            $issues.Add([pscustomobject]@{ code = 'workspace-config-library-filter-null'; fieldPath = 'workspace.excludeLibraries'; path = $workspaceConfigPath; line = $null; column = $null; message = 'excludeLibraries 不能为 null。' })
        }
        if ($propertyNames -contains 'resultRetentionDays' -and [int]$workspaceConfig.resultRetentionDays -le 0) {
            $issues.Add([pscustomobject]@{ code = 'workspace-config-retention-invalid'; fieldPath = 'workspace.resultRetentionDays'; path = $workspaceConfigPath; line = $null; column = $null; message = 'resultRetentionDays 必须大于 0。' })
        }
    }
    catch {
        $issues.Add([pscustomobject]@{ code = 'workspace-config-json-invalid'; path = $workspaceConfigPath; line = $null; column = $null; message = $_.Exception.Message })
    }

    try {
        $manifest = Get-Content -LiteralPath $TemplateManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($manifest.templateVersion -ne $script:ProductVersion) {
            $issues.Add([pscustomobject]@{ code = 'template-version-mismatch'; path = $TemplateManifestPath; line = $null; column = $null; message = "template manifest 必须为 $script:ProductVersion。" })
        }
    }
    catch {
        $issues.Add([pscustomobject]@{ code = 'template-manifest-invalid'; path = $TemplateManifestPath; line = $null; column = $null; message = $_.Exception.Message })
    }

    $cliPath = Join-Path $ToolkitRoot 'runtime\cli\win-x86\PbBridge.Cli.exe'
    if (Test-Path -LiteralPath $cliPath -PathType Leaf) {
        $resolverOutput = & $cliPath workspace context --repo-root $StagingRoot --workspace $WorkspaceId 2>&1
        $resolverExitCode = $LASTEXITCODE
        $resolverText = (($resolverOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
        if ($resolverExitCode -ne 0) {
            $issues.Add([pscustomobject]@{ code = 'workspace-context-resolver-rejected'; fieldPath = 'workspace'; path = $workspaceConfigPath; line = $null; column = $null; message = "Core workspace resolver 拒绝候选配置：$resolverText" })
        }
        else {
            try {
                $resolved = $resolverText | ConvertFrom-Json
                if ([string]$resolved.workspaceId -ne $WorkspaceId -or
                    [string]::IsNullOrWhiteSpace([string]$resolved.manifestPath) -or
                    [string]::IsNullOrWhiteSpace([string]$resolved.manifestSelectionSource)) {
                    $issues.Add([pscustomobject]@{ code = 'workspace-context-resolver-evidence-invalid'; fieldPath = 'workspace'; path = $workspaceConfigPath; line = $null; column = $null; message = 'Core workspace resolver 未返回完整身份或 Manifest 选择证据。' })
                }
            }
            catch {
                $issues.Add([pscustomobject]@{ code = 'workspace-context-resolver-json-invalid'; fieldPath = 'workspace'; path = $workspaceConfigPath; line = $null; column = $null; message = $_.Exception.Message })
            }
        }
    }

    return $issues.ToArray()
}

function Restore-PbBridgeMigration {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Entries)

    $errors = New-Object System.Collections.Generic.List[string]
    foreach ($entry in @($Entries | Sort-Object targetPath -Descending)) {
        try {
            if ($entry.existed) {
                $parent = Split-Path -Parent $entry.targetPath
                if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                Copy-Item -LiteralPath $entry.backupPath -Destination $entry.targetPath -Force
            }
            elseif (Test-Path -LiteralPath $entry.targetPath) {
                Remove-Item -LiteralPath $entry.targetPath -Force
            }
        }
        catch {
            $errors.Add("$($entry.targetPath): $($_.Exception.Message)")
        }
    }

    return $errors.ToArray()
}

function Write-PbBridgeJsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value,
        [int]$Depth = 30
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $json = $Value | ConvertTo-Json -Depth $Depth
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

function Get-PbBridgeCanonicalHash {
    param([Parameter(Mandatory = $true)]$Value)

    $canonical = ConvertTo-PbBridgeCanonicalJson -Value $Value
    return Get-PbBridgeTextSha256 -Text $canonical
}

function Get-PbBridgeGovernancePath {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $path = $null
    if ($Value -is [System.Collections.IDictionary]) {
        if (-not $Value.Contains('path')) { throw "governance-path-missing: $Context" }
        $path = [string]$Value['path']
    }
    else {
        $property = $Value.PSObject.Properties['path']
        if ($null -eq $property) { throw "governance-path-missing: $Context" }
        $path = [string]$property.Value
    }
    if ([string]::IsNullOrWhiteSpace($path)) { throw "governance-path-empty: $Context" }
    return $path
}

function Sort-PbBridgeGovernancePathItems {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Items,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $records = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($Items)) {
        $path = Get-PbBridgeGovernancePath -Value $item -Context $Context
        if (-not $seen.Add($path)) { throw "governance-path-duplicate: $Context path=$path" }
        $records.Add([pscustomobject]@{ Path = $path; Value = $item })
    }
    $records.Sort([System.Comparison[object]]{
        param($left, $right)
        return [System.StringComparer]::Ordinal.Compare([string]$left.Path, [string]$right.Path)
    })
    return @($records | ForEach-Object { $_.Value })
}

function Test-PbBridgeGovernancePathItemsNormalized {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Items,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $previousPath = $null
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($Items)) {
        $path = Get-PbBridgeGovernancePath -Value $item -Context $Context
        if (-not $seen.Add($path)) { throw "governance-path-duplicate: $Context path=$path" }
        if ($null -ne $previousPath -and [System.StringComparer]::Ordinal.Compare($previousPath, $path) -gt 0) {
            throw "governance-path-not-normalized: $Context path=$path"
        }
        $previousPath = $path
    }
    return $true
}

function Read-PbBridgeMigrationPolicy {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)

    $policyPath = Join-Path $ProjectRoot '.pbbridge\migration-policy.json'
    $issues = New-Object System.Collections.Generic.List[object]
    $files = New-Object System.Collections.Generic.List[object]
    $document = $null
    if (Test-Path -LiteralPath $policyPath -PathType Leaf) {
        try {
            $document = [System.IO.File]::ReadAllText($policyPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        }
        catch {
            $issues.Add([pscustomobject]@{ code = 'migration-policy-json-invalid'; path = '.pbbridge/migration-policy.json'; message = $_.Exception.Message })
        }
    }

    if ($null -ne $document) {
        if ([string]$document.schemaName -ne 'pbbridge-template-migration-policy' -or [int]$document.schemaVersion -ne 1) {
            $issues.Add([pscustomobject]@{ code = 'migration-policy-contract-invalid'; path = '.pbbridge/migration-policy.json'; message = 'migration policy 必须使用 pbbridge-template-migration-policy schemaVersion=1。' })
        }
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in @($document.files)) {
            $path = ([string]$entry.path).Trim().Replace('\', '/')
            $segments = @($path.Split('/') | Where-Object { $_ -ne '' })
            $canonicalPath = $segments -join '/'
            $invalidPath = [string]::IsNullOrWhiteSpace($path) -or
                [System.IO.Path]::IsPathRooted($path) -or
                $path.IndexOfAny([char[]]'*?[]') -ge 0 -or
                $segments -contains '..' -or
                $segments -contains '.' -or
                $path.EndsWith('/', [System.StringComparison]::Ordinal) -or
                $path -cne $canonicalPath
            if ($invalidPath) {
                $issues.Add([pscustomobject]@{ code = 'migration-policy-path-invalid'; path = $path; message = 'policy path 必须是无 glob、无越界的 canonical 仓库相对文件路径。' })
                continue
            }
            if (-not $seen.Add($path)) {
                $issues.Add([pscustomobject]@{ code = 'migration-policy-path-conflict'; path = $path; message = 'policy 不得包含重复或大小写冲突路径。' })
                continue
            }
            if ([string]$entry.ownership -ne 'project-custom' -or [string]$entry.action -ne 'preserve') {
                $issues.Add([pscustomobject]@{ code = 'migration-policy-action-invalid'; path = $path; message = '首版 policy 只允许 project-custom/preserve。' })
                continue
            }
            if ($entry.PSObject.Properties.Name -contains 'reason' -and [string]::IsNullOrWhiteSpace([string]$entry.reason)) {
                $issues.Add([pscustomobject]@{ code = 'migration-policy-reason-empty'; path = $path; message = '存在 reason 字段时不得为空白。' })
                continue
            }
            $resolved = Resolve-PbBridgePathInsideRoot -Root $ProjectRoot -Path (Join-Path $ProjectRoot $path) -ReasonCode 'migration-policy-path-outside-project'
            if (Test-Path -LiteralPath $resolved -PathType Container) {
                $issues.Add([pscustomobject]@{ code = 'migration-policy-directory-not-allowed'; path = $path; message = 'policy 只能声明文件，禁止目录级豁免。' })
                continue
            }
            $files.Add([ordered]@{
                path = $path
                ownership = 'project-custom'
                action = 'preserve'
                reason = if ($entry.PSObject.Properties.Name -contains 'reason') { [string]$entry.reason } else { $null }
            })
        }
    }

    $normalizedFiles = @(Sort-PbBridgeGovernancePathItems -Items $files.ToArray() -Context 'migration-policy')
    $semantic = [ordered]@{
        schemaName = 'pbbridge-template-migration-policy'
        schemaVersion = 1
        files = $normalizedFiles
    }
    return [pscustomobject]@{
        path = $policyPath
        exists = Test-Path -LiteralPath $policyPath -PathType Leaf
        files = $semantic.files
        policyHash = Get-PbBridgeCanonicalHash -Value $semantic
        issues = $issues.ToArray()
    }
}

function Get-PbBridgeMigrationIndex {
    param([Parameter(Mandatory = $true)][string]$MigrationRoot)

    $indexPath = Join-Path $MigrationRoot 'index.json'
    if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
        return [pscustomobject]@{ path = $indexPath; entries = @() }
    }
    try {
        $document = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        if ([string]$document.schemaName -ne 'pbbridge-template-migration-index' -or [int]$document.schemaVersion -ne 8) {
            throw 'migration-index-contract-invalid'
        }
        return [pscustomobject]@{ path = $indexPath; entries = @($document.entries) }
    }
    catch {
        throw "migration-index-invalid: $indexPath`: $($_.Exception.Message)"
    }
}

function Save-PbBridgeMigrationIndex {
    param(
        [Parameter(Mandatory = $true)][string]$MigrationRoot,
        [Parameter(Mandatory = $true)][string]$PlanHash,
        [Parameter(Mandatory = $true)][string]$MigrationId,
        [Parameter(Mandatory = $true)][string]$TransactionRoot
    )

    $index = Get-PbBridgeMigrationIndex -MigrationRoot $MigrationRoot
    $entries = New-Object System.Collections.Generic.List[object]
    foreach ($entry in @($index.entries | Where-Object { [string]$_.planHash -ne $PlanHash })) {
        $entries.Add($entry)
    }
    $entries.Add([ordered]@{
        planHash = $PlanHash
        migrationId = $MigrationId
        transactionRoot = $TransactionRoot
        updatedAt = [DateTimeOffset]::UtcNow.ToString('O')
    })
    $document = [ordered]@{
        schemaName = 'pbbridge-template-migration-index'
        schemaVersion = 8
        productVersion = $script:ProductVersion
        entries = @($entries.ToArray() | Sort-Object planHash)
    }
    Write-PbBridgeJsonFile -Path $index.path -Value $document
    return $document
}

function Resolve-PbBridgeTransactionForPlan {
    param(
        [Parameter(Mandatory = $true)][string]$MigrationRoot,
        [Parameter(Mandatory = $true)][string]$PlanHash
    )

    $index = Get-PbBridgeMigrationIndex -MigrationRoot $MigrationRoot
    $entry = @($index.entries | Where-Object { [string]$_.planHash -eq $PlanHash }) | Select-Object -First 1
    if ($null -eq $entry) { return $null }
    return [pscustomobject]@{
        migrationId = [string]$entry.migrationId
        transactionRoot = [string]$entry.transactionRoot
    }
}

function Get-PbBridgeUnresolvedRecovery {
    param([Parameter(Mandatory = $true)][string]$MigrationRoot)

    $unresolved = New-Object System.Collections.Generic.List[object]
    $index = Get-PbBridgeMigrationIndex -MigrationRoot $MigrationRoot
    foreach ($entry in @($index.entries)) {
        $transactionRoot = [string]$entry.transactionRoot
        $resultPath = Join-Path $transactionRoot 'result.json'
        if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { continue }
        try {
            $result = [System.IO.File]::ReadAllText($resultPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
            if ([string]$result.outcome -ne 'recovery-required') { continue }
            $manifestPath = Join-Path $transactionRoot 'recovery-manifest.json'
            if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
                $unresolved.Add([pscustomobject]@{ migrationId = [string]$entry.migrationId; recoveryManifestPath = $manifestPath; targetPath = $null; reason = 'recovery-manifest-missing' })
                continue
            }
            $recovery = [System.IO.File]::ReadAllText($manifestPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
            foreach ($recoveryEntry in @($recovery.entries)) {
                $targetPath = [string]$recoveryEntry.targetPath
                $exists = Test-Path -LiteralPath $targetPath -PathType Leaf
                $resolved = if ([bool]$recoveryEntry.existed) {
                    $exists -and (Get-PbBridgeSha256 -Path $targetPath) -eq [string]$recoveryEntry.originalSha256
                }
                else {
                    -not $exists
                }
                if (-not $resolved) {
                    $unresolved.Add([pscustomobject]@{ migrationId = [string]$entry.migrationId; recoveryManifestPath = $manifestPath; targetPath = $targetPath; reason = 'raw-hash-not-restored' })
                }
            }
        }
        catch {
            $unresolved.Add([pscustomobject]@{ migrationId = [string]$entry.migrationId; recoveryManifestPath = (Join-Path $transactionRoot 'recovery-manifest.json'); targetPath = $null; reason = 'recovery-audit-invalid' })
        }
    }
    return $unresolved.ToArray()
}

function Read-PbBridgeDecisionSet {
    param(
        [Parameter(Mandatory = $true)][string]$TransactionRoot,
        [Parameter(Mandatory = $true)][string]$PlanHash
    )

    $path = Join-Path $TransactionRoot 'decisions.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return [pscustomobject]@{ path = $path; decisions = @(); decisionSetHash = Get-PbBridgeCanonicalHash -Value @() }
    }
    $document = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    if ([string]$document.schemaName -ne 'pbbridge-template-migration-decisions' -or
        [int]$document.schemaVersion -ne 8 -or [string]$document.planHash -ne $PlanHash) {
        throw "migration-decisions-invalid: $path"
    }
    $decisions = @(Sort-PbBridgeGovernancePathItems -Items @($document.decisions) -Context 'decision-set-read')
    $actualHash = Get-PbBridgeCanonicalHash -Value $decisions
    if ([string]$document.decisionSetHash -ne $actualHash) {
        throw "migration-decisions-hash-mismatch: $path"
    }
    return [pscustomobject]@{ path = $path; decisions = $decisions; decisionSetHash = $actualHash }
}

function Import-PbBridgeReusableDecisions {
    param(
        [Parameter(Mandatory = $true)][string]$MigrationRoot,
        [Parameter(Mandatory = $true)][string]$TransactionRoot,
        [Parameter(Mandatory = $true)][string]$PlanHash,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$DecisionRequests
    )

    Test-PbBridgeGovernancePathItemsNormalized -Items $DecisionRequests -Context 'decision-requests' | Out-Null
    $current = Read-PbBridgeDecisionSet -TransactionRoot $TransactionRoot -PlanHash $PlanHash
    $decisions = New-Object System.Collections.Generic.List[object]
    foreach ($decision in @($current.decisions)) { $decisions.Add($decision) }
    $index = Get-PbBridgeMigrationIndex -MigrationRoot $MigrationRoot
    $changed = $false

    foreach ($request in @($DecisionRequests)) {
        if (@($decisions | Where-Object { [string]$_.path -eq [string]$request.path }).Count -gt 0) { continue }
        foreach ($entry in @($index.entries | Where-Object { [string]$_.planHash -ne $PlanHash } | Sort-Object updatedAt -Descending)) {
            $priorPlanPath = Join-Path ([string]$entry.transactionRoot) 'plan.json'
            $priorDecisionPath = Join-Path ([string]$entry.transactionRoot) 'decisions.json'
            if (-not (Test-Path -LiteralPath $priorPlanPath -PathType Leaf) -or
                -not (Test-Path -LiteralPath $priorDecisionPath -PathType Leaf)) { continue }
            try {
                $priorPlan = [System.IO.File]::ReadAllText($priorPlanPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
                if ([string]$priorPlan.schemaName -ne 'pbbridge-v7-template-migration-plan' -or
                    [int]$priorPlan.schemaVersion -ne 8 -or
                    [string]$priorPlan.planHash -ne [string]$entry.planHash) { continue }
                $priorRequest = @($priorPlan.decisionRequests | Where-Object {
                    [string]$_.path -eq [string]$request.path -and
                    [string]$_.decisionIdentityHash -eq [string]$request.decisionIdentityHash
                }) | Select-Object -First 1
                if ($null -eq $priorRequest) { continue }
                $priorSet = Read-PbBridgeDecisionSet -TransactionRoot ([string]$entry.transactionRoot) -PlanHash ([string]$entry.planHash)
                $priorDecision = @($priorSet.decisions | Where-Object {
                    [string]$_.path -eq [string]$request.path -and
                    [string]$_.action -eq 'preserve-custom-and-continue' -and
                    [string]$_.decisionIdentityHash -eq [string]$request.decisionIdentityHash
                }) | Select-Object -First 1
                if ($null -eq $priorDecision) { continue }

                $decisions.Add([ordered]@{
                    path = [string]$request.path
                    action = 'preserve-custom-and-continue'
                    reason = [string]$priorDecision.reason
                    actor = if ([string]::IsNullOrWhiteSpace([string]$priorDecision.actor)) { $null } else { [string]$priorDecision.actor }
                    workspaceIds = @($request.workspaceIds | Sort-Object -Unique)
                    decisionIdentityHash = [string]$request.decisionIdentityHash
                    derivedFromPlanHash = [string]$entry.planHash
                })
                $changed = $true
                break
            }
            catch {
                continue
            }
        }
    }

    if ($changed) {
        $sortedDecisions = @(Sort-PbBridgeGovernancePathItems -Items $decisions.ToArray() -Context 'decision-set-write')
        $document = [ordered]@{
            schemaName = 'pbbridge-template-migration-decisions'
            schemaVersion = 8
            productVersion = $script:ProductVersion
            planHash = $PlanHash
            decisionSetHash = Get-PbBridgeCanonicalHash -Value $sortedDecisions
            generatedAt = [DateTimeOffset]::UtcNow.ToString('O')
            decisions = $sortedDecisions
        }
        Write-PbBridgeJsonFile -Path $current.path -Value $document
    }
    return Read-PbBridgeDecisionSet -TransactionRoot $TransactionRoot -PlanHash $PlanHash
}

function Test-PbBridgePreservedCompatibility {
    param(
        [Parameter(Mandatory = $true)][string]$StagingRoot,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$PreservedEntries,
        [Parameter(Mandatory = $true)][string]$ToolkitRoot
    )

    $checks = New-Object System.Collections.Generic.List[object]
    $issues = New-Object System.Collections.Generic.List[object]
    $stagingToolkitLink = Join-Path $StagingRoot '.pbbridge\PbBridge.Toolkit'
    $createdToolkitLink = $false
    $stagingSharedModulePath = Join-Path $StagingRoot 'scripts\PbBridge.Wrapper.psm1'
    $createdSharedModuleSupport = $false
    $smokeRoot = $StagingRoot
    $createdSmokeRoot = $false
    try {
        if (-not (Test-Path -LiteralPath $stagingToolkitLink)) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $stagingToolkitLink) -Force | Out-Null
            New-Item -ItemType Junction -Path $stagingToolkitLink -Target $ToolkitRoot | Out-Null
            $createdToolkitLink = $true
        }
        if (-not (Test-Path -LiteralPath $stagingSharedModulePath -PathType Leaf)) {
            $toolkitSharedModulePath = Join-Path $ToolkitRoot 'templates\external-project\PbBridge.Wrapper.psm1'
            if (Test-Path -LiteralPath $toolkitSharedModulePath -PathType Leaf) {
                New-Item -ItemType Directory -Path (Split-Path -Parent $stagingSharedModulePath) -Force | Out-Null
                Copy-Item -LiteralPath $toolkitSharedModulePath -Destination $stagingSharedModulePath -Force
                $createdSharedModuleSupport = $true
            }
        }
        if ([System.OperatingSystem]::IsWindows()) {
            $smokeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pbbridge-migration-smoke-{0}" -f [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Junction -Path $smokeRoot -Target $StagingRoot | Out-Null
            $createdSmokeRoot = $true
        }

        foreach ($entry in @($PreservedEntries | Sort-Object targetPath -Unique)) {
            $path = Join-Path $smokeRoot ([string]$entry.targetPath)
            $extension = [System.IO.Path]::GetExtension($path)
            if ($extension -notin @('.ps1', '.psm1')) { continue }

            $parse = Get-PbBridgePowerShellAst -Path $path
            $astStatus = if ($parse.errors.Count -eq 0) { 'clear' } else { 'blocked' }
            $checks.Add([pscustomobject]@{ name = 'powershell-ast'; path = [string]$entry.targetPath; status = $astStatus })
            foreach ($error in $parse.errors) {
                $issues.Add([pscustomobject]@{ code = 'preserved-powershell-ast-invalid'; path = [string]$entry.targetPath; line = $error.line; column = $error.column; message = $error.message })
            }
            if ($parse.errors.Count -gt 0) { continue }

            $parameterNames = @($parse.ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.ParameterAst] }, $true) |
                ForEach-Object { $_.Name.VariablePath.UserPath } | Sort-Object -Unique)
            $checks.Add([pscustomobject]@{ name = 'cli-parameters'; path = [string]$entry.targetPath; status = 'clear'; workspaceSelector = if ($parameterNames -contains 'WorkspaceName') { 'wrapper-workspace-name' } else { 'not-applicable' } })

            if ([System.IO.Path]::GetFileName($path) -eq 'PbBridge.Wrapper.psm1') {
                try {
                    $module = Import-Module -Name $path -Force -PassThru -ErrorAction Stop
                    $checks.Add([pscustomobject]@{ name = 'shared-module-import'; path = [string]$entry.targetPath; status = 'clear'; exportedCommandCount = @($module.ExportedCommands.Keys).Count })
                    Remove-Module -ModuleInfo $module -Force -ErrorAction SilentlyContinue
                }
                catch {
                    $checks.Add([pscustomobject]@{ name = 'shared-module-import'; path = [string]$entry.targetPath; status = 'blocked'; exportedCommandCount = 0 })
                    $issues.Add([pscustomobject]@{ code = 'preserved-shared-module-import-failed'; path = [string]$entry.targetPath; line = $null; column = $null; message = $_.Exception.Message })
                }
            }

            if ($extension -eq '.ps1' -and ($parameterNames -contains 'CliHelp' -or $parameterNames -contains 'Help')) {
                $cliPath = Join-Path $ToolkitRoot 'runtime\cli\win-x86\PbBridge.Cli.exe'
                if (Test-Path -LiteralPath $cliPath -PathType Leaf) {
                    $helpArgument = if ($parameterNames -contains 'CliHelp') { '-CliHelp' } else { '-Help' }
                    $helpOutput = & (Get-Process -Id $PID).Path -NoLogo -NoProfile -ExecutionPolicy Bypass -File $path $helpArgument 2>&1 | Out-String
                    $helpExitCode = $LASTEXITCODE
                    $checks.Add([pscustomobject]@{ name = 'recommended-wrapper-help-smoke'; path = [string]$entry.targetPath; status = if ($helpExitCode -eq 0) { 'clear' } else { 'blocked' }; exitCode = $helpExitCode })
                    if ($helpExitCode -ne 0) {
                        $issues.Add([pscustomobject]@{ code = 'preserved-wrapper-help-smoke-failed'; path = [string]$entry.targetPath; line = $null; column = $null; message = $helpOutput.Trim() })
                    }
                }
                else {
                    $checks.Add([pscustomobject]@{ name = 'recommended-wrapper-help-smoke'; path = [string]$entry.targetPath; status = 'not-applicable'; exitCode = $null })
                }
            }
        }
    }
    finally {
        if ($createdSmokeRoot -and (Test-Path -LiteralPath $smokeRoot)) {
            [System.IO.Directory]::Delete($smokeRoot, $false)
        }
        if ($createdToolkitLink -and (Test-Path -LiteralPath $stagingToolkitLink)) {
            [System.IO.Directory]::Delete($stagingToolkitLink, $false)
        }
        if ($createdSharedModuleSupport -and (Test-Path -LiteralPath $stagingSharedModulePath -PathType Leaf)) {
            Remove-Item -LiteralPath $stagingSharedModulePath -Force
        }
    }
    return [pscustomobject]@{ checks = $checks.ToArray(); issues = $issues.ToArray() }
}

function ConvertTo-PbBridgePowerShellSingleQuotedLiteral {
    param([AllowEmptyString()][string]$Value)

    return "'" + $Value.Replace("'", "''") + "'"
}

function New-PbBridgeTemplateMigrationApplyCommand {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$ToolkitRoot,
        [Parameter(Mandatory = $true)][string]$WorkspaceId,
        [AllowEmptyString()][string]$PbwPath,
        [Parameter(Mandatory = $true)][string]$PlanHash
    )

    $entrypoint = Join-Path ([System.IO.Path]::GetFullPath($ToolkitRoot)) 'templates\external-project\pbbridge-template-migrate.ps1'
    $arguments = @(
        '&',
        (ConvertTo-PbBridgePowerShellSingleQuotedLiteral -Value $entrypoint),
        '-ProjectRoot',
        (ConvertTo-PbBridgePowerShellSingleQuotedLiteral -Value ([System.IO.Path]::GetFullPath($ProjectRoot))),
        '-ToolkitRoot',
        (ConvertTo-PbBridgePowerShellSingleQuotedLiteral -Value ([System.IO.Path]::GetFullPath($ToolkitRoot))),
        '-WorkspaceId',
        (ConvertTo-PbBridgePowerShellSingleQuotedLiteral -Value $WorkspaceId),
        '-PbwPath',
        (ConvertTo-PbBridgePowerShellSingleQuotedLiteral -Value $PbwPath),
        '-Apply',
        '-PlanHash',
        (ConvertTo-PbBridgePowerShellSingleQuotedLiteral -Value $PlanHash)
    )
    return $arguments -join ' '
}

function Invoke-PbBridgeMigrationDecision {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$ToolkitRoot,
        [Parameter(Mandatory = $true)][string]$PlanHash,
        [Parameter(Mandatory = $true)][string[]]$DecisionPath,
        [Parameter(Mandatory = $true)][string]$Reason,
        [string]$Actor = '',
        [string]$OutputPath = ''
    )

    if ($PlanHash -notmatch '^[a-f0-9]{64}$') { throw "migration-plan-hash-invalid: $PlanHash" }
    if ([string]::IsNullOrWhiteSpace($Reason)) { throw 'migration-decision-reason-required' }
    $projectRootFull = [System.IO.Path]::GetFullPath($ProjectRoot)
    $migrationRoot = Join-Path $projectRootFull '.pbbridge\local\migrations'
    $transaction = Resolve-PbBridgeTransactionForPlan -MigrationRoot $migrationRoot -PlanHash $PlanHash
    if ($null -eq $transaction) { throw "migration-plan-not-found: $PlanHash" }
    $planPath = Join-Path $transaction.transactionRoot 'plan.json'
    if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) { throw "migration-plan-not-found: $planPath" }
    $plan = [System.IO.File]::ReadAllText($planPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    if ([string]$plan.schemaName -ne 'pbbridge-v7-template-migration-plan' -or
        [int]$plan.schemaVersion -ne 8 -or [string]$plan.planHash -ne $PlanHash) {
        throw "migration-plan-contract-invalid: $planPath"
    }

    $policy = Read-PbBridgeMigrationPolicy -ProjectRoot $projectRootFull
    if ($policy.issues.Count -gt 0) { throw "migration-policy-invalid: $($policy.issues[0].code)" }
    if ([string]$plan.policy.policyHash -ne [string]$policy.policyHash) {
        throw 'migration-plan-stale: migration-policy-changed'
    }

    $requestedPaths = @($plan.decisionRequests | ForEach-Object { [string]$_.path })
    $existing = Read-PbBridgeDecisionSet -TransactionRoot $transaction.transactionRoot -PlanHash $PlanHash
    $decisions = New-Object System.Collections.Generic.List[object]
    foreach ($decision in @($existing.decisions)) { $decisions.Add($decision) }
    foreach ($rawPath in @($DecisionPath)) {
        $path = $rawPath.Trim().Replace('\', '/')
        if ($requestedPaths -notcontains $path) { throw "migration-decision-path-not-in-plan: $path" }
        $policyEntry = @($policy.files | Where-Object { [string]$_.path -eq $path }) | Select-Object -First 1
        if ($null -eq $policyEntry) { throw "migration-policy-entry-required: $path" }
        $prior = @($decisions | Where-Object { [string]$_.path -eq $path }) | Select-Object -First 1
        $candidate = [ordered]@{
            path = $path
            action = 'preserve-custom-and-continue'
            reason = $Reason.Trim()
            actor = if ([string]::IsNullOrWhiteSpace($Actor)) { $null } else { $Actor.Trim() }
            workspaceIds = @($plan.decisionRequests | Where-Object { [string]$_.path -eq $path } | ForEach-Object { @($_.workspaceIds) } | Sort-Object -Unique)
            decisionIdentityHash = [string](@($plan.decisionRequests | Where-Object { [string]$_.path -eq $path })[0].decisionIdentityHash)
            derivedFromPlanHash = $null
        }
        if ($null -ne $prior) {
            if ((Get-PbBridgeCanonicalHash -Value $prior) -ne (Get-PbBridgeCanonicalHash -Value $candidate)) {
                throw "migration-decision-conflict: $path"
            }
            continue
        }
        $decisions.Add($candidate)
    }

    $sortedDecisions = @(Sort-PbBridgeGovernancePathItems -Items $decisions.ToArray() -Context 'decision-set-write')
    $decisionSetHash = Get-PbBridgeCanonicalHash -Value $sortedDecisions
    $decisionDocument = [ordered]@{
        schemaName = 'pbbridge-template-migration-decisions'
        schemaVersion = 8
        productVersion = $script:ProductVersion
        planHash = $PlanHash
        decisionSetHash = $decisionSetHash
        generatedAt = [DateTimeOffset]::UtcNow.ToString('O')
        decisions = $sortedDecisions
    }
    Write-PbBridgeJsonFile -Path $existing.path -Value $decisionDocument

    $waiting = @($requestedPaths | Where-Object { $_ -notin @($sortedDecisions.path) } | Sort-Object -Unique)
    $resultPath = Join-Path $transaction.transactionRoot 'result.json'
    $result = [ordered]@{
        schemaName = 'pbbridge-v7-template-migration'
        schemaVersion = 8
        productVersion = $script:ProductVersion
        generatedAt = [DateTimeOffset]::UtcNow.ToString('O')
        migrationId = $transaction.migrationId
        phase = 'decide'
        outcome = if ($waiting.Count -eq 0) { 'ready-to-apply' } else { 'awaiting-decisions' }
        planHash = $PlanHash
        decisionSetHash = $decisionSetHash
        decisions = $sortedDecisions
        awaitingDecisions = $waiting
        audit = [ordered]@{
            planPath = $planPath
            decisionsPath = $existing.path
            resultPath = $resultPath
            indexPath = Join-Path $migrationRoot 'index.json'
        }
        nextAction = if ($waiting.Count -eq 0) {
            New-PbBridgeTemplateMigrationApplyCommand `
                -ProjectRoot $projectRootFull `
                -ToolkitRoot $ToolkitRoot `
                -WorkspaceId ([string]$plan.semanticPlan.workspaceId) `
                -PbwPath ([string]$plan.semanticPlan.pbwPath) `
                -PlanHash $PlanHash
        }
        else {
            '继续为 awaitingDecisions 生成 preserve-custom-and-continue 决定。'
        }
    }
    Write-PbBridgeJsonFile -Path $resultPath -Value $result
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $outputPathFull = Resolve-PbBridgePathInsideRoot -Root $projectRootFull -Path $OutputPath -ReasonCode 'migration-output-outside-project'
        Write-PbBridgeJsonFile -Path $outputPathFull -Value $result
    }
    return [pscustomobject]$result
}

function Invoke-PbBridgeTemplateMigration {
    [CmdletBinding(DefaultParameterSetName = 'Plan', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$ToolkitRoot,
        [string]$WorkspaceId = 'default',
        [string]$PbwPath = '',
        [string]$OutputPath = '',
        [Parameter(ParameterSetName = 'Plan')][switch]$Plan,
        [Parameter(Mandatory = $true, ParameterSetName = 'Apply')][switch]$Apply,
        [Parameter(Mandatory = $true, ParameterSetName = 'Decide')][switch]$Decide,
        [Parameter(ParameterSetName = 'Apply')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Decide')]
        [string]$PlanHash = '',
        [Parameter(Mandatory = $true, ParameterSetName = 'Decide')]
        [Alias('Path')]
        [string[]]$DecisionPath,
        [Parameter(Mandatory = $true, ParameterSetName = 'Decide')]
        [string]$Reason,
        [Parameter(ParameterSetName = 'Decide')]
        [string]$Actor = '',
        [ValidateSet('none', 'candidate-syntax', 'candidate-identity', 'file-locked', 'write-truncated', 'post-install-hash', 'rollback-failure')]
        [string]$FailureInjection = 'none'
    )

    $projectRootFull = [System.IO.Path]::GetFullPath($ProjectRoot)
    $toolkitRootFull = [System.IO.Path]::GetFullPath($ToolkitRoot)
    if ($Decide.IsPresent) {
        return Invoke-PbBridgeMigrationDecision `
            -ProjectRoot $projectRootFull `
            -ToolkitRoot $toolkitRootFull `
            -PlanHash $PlanHash `
            -DecisionPath $DecisionPath `
            -Reason $Reason `
            -Actor $Actor `
            -OutputPath $OutputPath
    }
    if ($WorkspaceId -notmatch '^[a-z0-9_-]+$') { throw "workspace-id-invalid: $WorkspaceId" }
    $templateRoot = Join-Path $toolkitRootFull 'templates\external-project'
    $templateManifestPath = Join-Path $templateRoot 'template-manifest.json'
    if (-not (Test-Path -LiteralPath $templateManifestPath -PathType Leaf)) { throw "template-manifest-not-found: $templateManifestPath" }
    $manifest = Get-Content -LiteralPath $templateManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $provenanceRegistry = $null
    $provenanceRegistryPath = $null
    if ($manifest.PSObject.Properties.Name -contains 'provenanceRegistry' -and
        -not [string]::IsNullOrWhiteSpace([string]$manifest.provenanceRegistry)) {
        $provenanceRegistryPath = Join-Path $templateRoot ([string]$manifest.provenanceRegistry)
        if (-not (Test-Path -LiteralPath $provenanceRegistryPath -PathType Leaf)) {
            throw "managed-provenance-registry-not-found: $provenanceRegistryPath"
        }
        $provenanceRegistry = Get-Content -LiteralPath $provenanceRegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ([string]$provenanceRegistry.schemaName -ne 'pbbridge-managed-template-provenance' -or
            [int]$provenanceRegistry.schemaVersion -ne 2) {
            throw "managed-provenance-registry-invalid: $provenanceRegistryPath"
        }
    }

    $runId = [guid]::NewGuid().ToString('N')
    $migrationRoot = Join-Path $projectRootFull '.pbbridge\local\migrations'
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path $migrationRoot ("results\{0}-{1}.json" -f $WorkspaceId, $runId)
    }
    $outputPathFull = Resolve-PbBridgePathInsideRoot -Root $projectRootFull -Path $OutputPath -ReasonCode 'migration-output-outside-project'
    $transactionRoot = Join-Path $projectRootFull (".pbbridge\local\migrations\transactions\{0}" -f $runId)
    $stagingRoot = Join-Path $transactionRoot 'staging'
    $backupRoot = Join-Path $transactionRoot 'backup'
    $recoveryManifestPath = Join-Path $transactionRoot 'recovery-manifest.json'
    $candidateManifestPath = Join-Path $transactionRoot 'candidate-manifest.json'

    $fieldMappings = New-Object System.Collections.Generic.List[object]
    $manual = New-Object System.Collections.Generic.List[object]
    $decisionRequests = New-Object System.Collections.Generic.List[object]
    $preservedFiles = New-Object System.Collections.Generic.List[object]
    $installFiles = New-Object System.Collections.Generic.List[object]
    $assetClassifications = New-Object System.Collections.Generic.List[object]
    $configValues = [ordered]@{}
    $pbwPathWasExplicit = -not [string]::IsNullOrWhiteSpace($PbwPath)
    $policy = Read-PbBridgeMigrationPolicy -ProjectRoot $projectRootFull
    foreach ($issue in @($policy.issues)) {
        $manual.Add([pscustomobject]@{ file = $issue.path; code = $issue.code; message = $issue.message; line = $null; column = $null })
    }
    foreach ($recovery in @(Get-PbBridgeUnresolvedRecovery -MigrationRoot $migrationRoot)) {
        $manual.Add([pscustomobject]@{
            file = [string]$recovery.recoveryManifestPath
            code = 'migration-recovery-required'
            message = "迁移 $($recovery.migrationId) 尚未按 recovery manifest 恢复原始 rawSha256：$($recovery.targetPath)"
            line = $null
            column = $null
        })
    }

    foreach ($file in @($manifest.managedFiles | Where-Object { $_.mergeMode -eq 'overwrite-if-template-managed' })) {
        $templatePath = Join-Path $templateRoot ([string]$file.templatePath)
        $targetPath = Resolve-PbBridgePathInsideRoot -Root $projectRootFull -Path (Join-Path $projectRootFull ([string]$file.targetPath)) -ReasonCode 'managed-target-outside-project'
        if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
            $manual.Add([pscustomobject]@{ file = [string]$file.targetPath; code = 'template-file-missing'; message = "模板文件不存在：$templatePath"; line = $null; column = $null })
            continue
        }

        $classification = Resolve-PbBridgeManagedFileClassification `
            -TargetPath $targetPath `
            -TemplatePath $templatePath `
            -TargetRelativePath ([string]$file.targetPath) `
            -ProvenanceRegistry $provenanceRegistry
        $assetClassifications.Add([pscustomobject]@{
            targetPath = [string]$file.targetPath
            kind = if ($file.PSObject.Properties.Name -contains 'kind') { [string]$file.kind } elseif ([string]$file.templatePath -like '*.psm1') { 'powershell-module' } else { 'powershell-wrapper' }
            assetGroup = if ($file.PSObject.Properties.Name -contains 'assetGroup') { [string]$file.assetGroup } else { $null }
            classification = $classification.classification
            targetExists = $classification.targetExists
            targetSha256 = $classification.targetSha256
            rawSha256 = $classification.targetRawSha256
            normalizedTextSha256 = $classification.targetNormalizedTextSha256
            templateSha256 = $classification.templateSha256
            templateRawSha256 = $classification.templateRawSha256
            templateNormalizedTextSha256 = $classification.templateNormalizedTextSha256
            normalizationProfile = $classification.normalizationProfile
            normalizationSupported = $classification.normalizationSupported
            normalizationReasonCode = $classification.normalizationReasonCode
            matchedTemplateVersion = $classification.matchedTemplateVersion
            difference = $classification.difference
        })

        $relativePath = ([string]$file.targetPath).Replace('\', '/')
        $policyEntry = @($policy.files | Where-Object { [string]$_.path -eq $relativePath }) | Select-Object -First 1
        $policyPreserve = $classification.targetExists -and $null -ne $policyEntry
        $canAutoInstall = -not $classification.targetExists -or
            (-not $policyPreserve -and $classification.classification -in @('managed-known-exact', 'managed-known-format-variant'))
        if ($classification.targetExists -and
            $classification.classification -in @('managed-known-exact', 'managed-known-format-variant')) {
            if ([System.IO.Path]::GetExtension($targetPath) -in @('.ps1', '.psm1')) {
                $scan = Get-PbBridgeWrapperScan -TargetPath $targetPath -TemplatePath $templatePath -TargetRelativePath ([string]$file.targetPath)
                foreach ($item in $scan.mappings) { $fieldMappings.Add($item) }
                foreach ($item in @($scan.manual | Where-Object {
                    $_.code -in @('legacy-wrapper-syntax-invalid', 'candidate-template-syntax-invalid', 'dynamic-default-expression', 'static-value-not-provable', 'unsupported-static-value-type')
                })) { $manual.Add($item) }
            }
        }

        if ($classification.targetExists -and ($policyPreserve -or $classification.classification -in @('managed-modified', 'unmanaged'))) {
            if ($file.PSObject.Properties.Name -contains 'assetGroup' -and [string]$file.assetGroup -eq 'migration-bootstrap') {
                $manual.Add([pscustomobject]@{
                    file = $relativePath
                    code = 'template-migration-bootstrap-customization-unsupported'
                    message = 'migration-bootstrap 资产组包含未知自定义；请先人工备份并恢复到已知 provenance，禁止单成员保留或升级。'
                    line = $null
                    column = $null
                })
                continue
            }
            $request = [pscustomobject]@{
                path = $relativePath
                classification = $classification.classification
                rawSha256 = $classification.targetRawSha256
                normalizedTextSha256 = $classification.targetNormalizedTextSha256
                templateRawSha256 = $classification.templateRawSha256
                normalizationReasonCode = $classification.normalizationReasonCode
                policyDeclared = $null -ne $policyEntry
                workspaceIds = @($WorkspaceId)
                requiredAction = 'preserve-custom-and-continue'
                decisionIdentityHash = $null
            }
            $decisionRequests.Add($request)
            $preservedFiles.Add([pscustomobject]@{
                targetPath = $relativePath
                targetFullPath = $targetPath
                rawSha256 = $classification.targetRawSha256
                classification = $classification.classification
                workspaceIds = @($WorkspaceId)
            })
        }

        if ($canAutoInstall) {
            $installFiles.Add([pscustomobject]@{
                templatePath = $templatePath
                targetPath = $targetPath
                targetRelativePath = [string]$file.targetPath
                stagingPath = Join-Path $stagingRoot ([string]$file.targetPath)
                assetGroup = if ($file.PSObject.Properties.Name -contains 'assetGroup') { [string]$file.assetGroup } else { $null }
            })
        }
    }

    $bootstrapManifestFiles = @($manifest.managedFiles | Where-Object { $_.PSObject.Properties.Name -contains 'assetGroup' -and [string]$_.assetGroup -eq 'migration-bootstrap' })
    $bootstrapClassifications = @($assetClassifications | Where-Object { [string]$_.assetGroup -eq 'migration-bootstrap' })
    $bootstrapBlocked = @($manual | Where-Object { [string]$_.code -eq 'template-migration-bootstrap-customization-unsupported' }).Count -gt 0
    if ($bootstrapManifestFiles.Count -ne 2 -or $bootstrapClassifications.Count -ne 2) {
        $manual.Add([pscustomobject]@{ file = 'template-manifest.json'; code = 'template-migration-bootstrap-pair-incomplete'; message = 'migration-bootstrap manifest 或候选未完整声明两个成员。'; line = $null; column = $null })
        $bootstrapBlocked = $true
    }
    $bootstrapVersions = @($bootstrapClassifications | Where-Object targetExists | ForEach-Object { [string]$_.matchedTemplateVersion } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if (@($bootstrapClassifications | Where-Object targetExists).Count -eq 2 -and $bootstrapVersions.Count -ne 1) {
        $manual.Add([pscustomobject]@{ file = 'scripts/migration-bootstrap'; code = 'template-migration-bootstrap-pair-version-mismatch'; message = 'migration-bootstrap 两个现存成员的受管版本不一致。'; line = $null; column = $null })
        $bootstrapBlocked = $true
    }
    $bootstrapNeedsInstall = @($bootstrapClassifications | Where-Object { -not $_.targetExists -or $_.classification -in @('managed-known-exact', 'managed-known-format-variant') }).Count -gt 0
    if ($bootstrapBlocked) {
        for ($index = $installFiles.Count - 1; $index -ge 0; $index--) {
            if ([string]$installFiles[$index].assetGroup -eq 'migration-bootstrap') { $installFiles.RemoveAt($index) }
        }
    }
    elseif ($bootstrapNeedsInstall) {
        foreach ($file in $bootstrapManifestFiles) {
            if (@($installFiles | Where-Object { [string]$_.targetRelativePath -eq [string]$file.targetPath }).Count -gt 0) { continue }
            $templatePath = Join-Path $templateRoot ([string]$file.templatePath)
            if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
                $manual.Add([pscustomobject]@{ file = [string]$file.targetPath; code = 'template-migration-bootstrap-pair-incomplete'; message = "无法从当前 Toolkit 补齐 migration-bootstrap 候选：$templatePath"; line = $null; column = $null })
                continue
            }
            $targetPath = Resolve-PbBridgePathInsideRoot -Root $projectRootFull -Path (Join-Path $projectRootFull ([string]$file.targetPath)) -ReasonCode 'managed-target-outside-project'
            $installFiles.Add([pscustomobject]@{
                templatePath = $templatePath
                targetPath = $targetPath
                targetRelativePath = [string]$file.targetPath
                stagingPath = Join-Path $stagingRoot ([string]$file.targetPath)
                assetGroup = 'migration-bootstrap'
            })
        }
    }

    foreach ($mapping in $fieldMappings) {
        if ($configValues.Contains($mapping.configPath) -and
            (ConvertTo-Json $configValues[$mapping.configPath] -Compress) -ne (ConvertTo-Json $mapping.value -Compress)) {
            $manual.Add([pscustomobject]@{ file = $mapping.file; code = 'config-value-conflict'; message = "字段 $($mapping.configPath) 存在不同旧默认值。"; line = $null; column = $null })
        }
        else {
            if (Test-PbBridgeMeaningfulOverride -Value $mapping.value) {
                $configValues[$mapping.configPath] = $mapping.value
            }
        }
    }

    if ($configValues.Contains('workspace.id')) {
        $migratedId = [string]$configValues['workspace.id']
        if (-not [string]::IsNullOrWhiteSpace($migratedId) -and $migratedId -notmatch '^[a-z0-9_-]+$') {
            $manual.Add([pscustomobject]@{ file = 'workspace'; code = 'migrated-workspace-id-invalid'; message = "迁移出的 workspace id 无效：$migratedId"; line = $null; column = $null })
        }
        elseif (-not [string]::IsNullOrWhiteSpace($migratedId) -and $WorkspaceId -eq 'default') {
            $WorkspaceId = $migratedId
        }
    }

    if ([string]::IsNullOrWhiteSpace($PbwPath) -and $configValues.Contains('workspace.pbwPath')) {
        $PbwPath = [string]$configValues['workspace.pbwPath']
    }
    if ([string]::IsNullOrWhiteSpace($PbwPath)) {
        $existingWorkspacePathForPbw = Join-Path $projectRootFull ".pbbridge\workspaces\$WorkspaceId\workspace.json"
        if (Test-Path -LiteralPath $existingWorkspacePathForPbw -PathType Leaf) {
            try {
                $existingWorkspaceForPbw = Get-Content -LiteralPath $existingWorkspacePathForPbw -Raw -Encoding UTF8 | ConvertFrom-Json
                if (-not [string]::IsNullOrWhiteSpace([string]$existingWorkspaceForPbw.pbwPath)) {
                    $PbwPath = [string]$existingWorkspaceForPbw.pbwPath
                }
            }
            catch {
                # 既有配置的正式契约诊断在后续统一生成；此处仅尝试复用可读的 pbwPath。
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($PbwPath)) {
        $pbwCandidates = @(Get-ChildItem -LiteralPath $projectRootFull -Filter '*.pbw' -File -Recurse)
        if ($pbwCandidates.Count -eq 1) {
            $PbwPath = $pbwCandidates[0].FullName.Substring($projectRootFull.TrimEnd('\', '/').Length).TrimStart('\', '/')
        }
        else {
            $manual.Add([pscustomobject]@{ file = '.pbbridge/workspaces'; code = 'pbw-path-manual-migration-required'; message = '无法唯一确定 PBW；请通过 -PbwPath 指定 repo 内相对路径。'; line = $null; column = $null })
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($PbwPath)) {
        $pbwFull = [System.IO.Path]::GetFullPath((Join-Path $projectRootFull $PbwPath))
        Resolve-PbBridgePathInsideRoot -Root $projectRootFull -Path $pbwFull -ReasonCode 'pbw-path-outside-project' | Out-Null
        $PbwPath = $pbwFull.Substring($projectRootFull.TrimEnd('\', '/').Length).TrimStart('\', '/').Replace('\', '/')
    }

    $workspaceReferences = New-Object System.Collections.Generic.List[object]
    $existingProjectConfigPath = Join-Path $projectRootFull '.pbbridge\project.json'
    $existingProjectConfig = $null
    if (Test-Path -LiteralPath $existingProjectConfigPath -PathType Leaf) {
        try {
            $existingProjectConfig = Get-Content -LiteralPath $existingProjectConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($existingProjectConfig.schemaName -ne 'pbbridge-project-config' -or
                $existingProjectConfig.schemaVersion -ne 7 -or
                -not (Test-PbBridgeSupportedSourceProductVersion -ProductVersion ([string]$existingProjectConfig.productVersion))) {
                $manual.Add([pscustomobject]@{ file = '.pbbridge/project.json'; code = 'existing-project-config-contract-invalid'; message = "已有 project.json 不是受支持的 V7 配置，不能自动合并 workspace。支持产品版本：$(Get-PbBridgeSupportedSourceProductVersionText)。"; line = $null; column = $null })
            }
            else {
                foreach ($reference in @($existingProjectConfig.workspaces)) {
                    if ([string]$reference.id -ne $WorkspaceId) {
                        $workspaceReferences.Add([ordered]@{
                            id = [string]$reference.id
                            configurationPath = [string]$reference.configurationPath
                        })
                    }
                }
            }
        }
        catch {
            $manual.Add([pscustomobject]@{ file = '.pbbridge/project.json'; code = 'existing-project-config-json-invalid'; message = "已有 project.json 无法解析：$($_.Exception.Message)"; line = $null; column = $null })
        }
    }
    $workspaceReferences.Add([ordered]@{
        id = $WorkspaceId
        configurationPath = ".pbbridge/workspaces/$WorkspaceId/workspace.json"
    })

    $projectConfig = [ordered]@{
        schemaName = 'pbbridge-project-config'
        schemaVersion = 7
        productVersion = $script:ProductVersion
        workspaces = @($workspaceReferences.ToArray() | Sort-Object { [string]$_.id })
    }
    $existingWorkspaceConfig = $null
    $existingWorkspaceConfigPath = Join-Path $projectRootFull (".pbbridge\workspaces\{0}\workspace.json" -f $WorkspaceId)
    if (Test-Path -LiteralPath $existingWorkspaceConfigPath -PathType Leaf) {
        try {
            $candidateExistingWorkspace = Get-Content -LiteralPath $existingWorkspaceConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($candidateExistingWorkspace.schemaName -eq 'pbbridge-workspace-config' -and
                $candidateExistingWorkspace.schemaVersion -eq 7 -and
                (Test-PbBridgeSupportedSourceProductVersion -ProductVersion ([string]$candidateExistingWorkspace.productVersion)) -and
                [string]$candidateExistingWorkspace.id -eq $WorkspaceId) {
                $existingWorkspaceConfig = $candidateExistingWorkspace
            }
            else {
                $manual.Add([pscustomobject]@{ file = ".pbbridge/workspaces/$WorkspaceId/workspace.json"; code = 'existing-workspace-config-contract-invalid'; message = "已有 workspace.json 身份或版本无效，不能稳定合并。支持产品版本：$(Get-PbBridgeSupportedSourceProductVersionText)。"; line = $null; column = $null })
            }
        }
        catch {
            $manual.Add([pscustomobject]@{ file = ".pbbridge/workspaces/$WorkspaceId/workspace.json"; code = 'existing-workspace-config-json-invalid'; message = "已有 workspace.json 无法解析：$($_.Exception.Message)"; line = $null; column = $null })
        }
    }
    $workspaceConfig = New-PbBridgeWorkspaceConfiguration -TemplateRoot $templateRoot -WorkspaceId $WorkspaceId -PbwPath $PbwPath
    Merge-PbBridgeWorkspaceConfiguration -Configuration $workspaceConfig -ExistingConfiguration $existingWorkspaceConfig -Overrides $configValues -PbwPathWasExplicit:$pbwPathWasExplicit
    $workspaceConfig.productVersion = $script:ProductVersion
    $workspaceConfig.id = $WorkspaceId
    if ($pbwPathWasExplicit) { $workspaceConfig.pbwPath = $PbwPath }

    foreach ($fieldName in @('manifestPath', 'sourceLayout', 'scanScope', 'verifyPolicyMode')) {
        if ([string]::IsNullOrWhiteSpace([string]$workspaceConfig[$fieldName])) {
            $manual.Add([pscustomobject]@{
                file = ".pbbridge/workspaces/$WorkspaceId/workspace.json"
                code = 'workspace-config-semantic-field-empty'
                fieldPath = "workspace.$fieldName"
                message = "workspace 配置字段不能为空白：$fieldName。"
                line = $null
                column = $null
            })
        }
    }
    if ($null -eq $workspaceConfig.includeLibraries -or $null -eq $workspaceConfig.excludeLibraries) {
        $manual.Add([pscustomobject]@{ file = ".pbbridge/workspaces/$WorkspaceId/workspace.json"; code = 'workspace-config-library-filter-null'; fieldPath = 'workspace.includeLibraries/excludeLibraries'; message = 'includeLibraries 和 excludeLibraries 不能为 null。'; line = $null; column = $null })
    }
    if ([int]$workspaceConfig.resultRetentionDays -le 0) {
        $manual.Add([pscustomobject]@{ file = ".pbbridge/workspaces/$WorkspaceId/workspace.json"; code = 'workspace-config-retention-invalid'; fieldPath = 'workspace.resultRetentionDays'; message = 'resultRetentionDays 必须大于 0。'; line = $null; column = $null })
    }

    $projectConfigChanged = -not (Test-PbBridgeJsonEquivalent -Left $existingProjectConfig -Right ([pscustomobject]$projectConfig))
    $workspaceConfigChanged = -not (Test-PbBridgeJsonEquivalent -Left $existingWorkspaceConfig -Right ([pscustomobject]$workspaceConfig))
    $configurationPlan = New-Object System.Collections.Generic.List[object]
    if ($projectConfigChanged) {
        $configurationPlan.Add([pscustomobject]@{ targetPath = '.pbbridge/project.json'; action = 'write-v7-project-config' })
    }
    if ($workspaceConfigChanged) {
        $configurationPlan.Add([pscustomobject]@{ targetPath = ".pbbridge/workspaces/$WorkspaceId/workspace.json"; action = 'write-v7-workspace-config' })
    }

    $configurationJson = [ordered]@{ project = $projectConfig; workspace = $workspaceConfig } | ConvertTo-Json -Depth 20 -Compress
    $configurationSha256 = Get-PbBridgeTextSha256 -Text $configurationJson
    $plannedInstallFiles = @(
        @($installFiles.ToArray() | ForEach-Object { [pscustomobject]@{ targetPath = $_.targetRelativePath; action = 'replace-with-v7-template' } }) +
        @($configurationPlan.ToArray())
    )
    $installPlan = New-Object System.Collections.Generic.List[object]
    foreach ($file in $installFiles) {
        $installPlan.Add([pscustomobject]@{
            targetPath = $file.targetRelativePath
            action = if (Test-Path -LiteralPath $file.targetPath -PathType Leaf) { 'replace' } else { 'create' }
            source = 'generated'
            workspaceId = $WorkspaceId
        })
    }
    foreach ($classification in $assetClassifications) {
        if ($classification.targetExists -and $classification.classification -in @('managed-modified', 'unmanaged')) {
            $installPlan.Add([pscustomobject]@{
                targetPath = $classification.targetPath
                action = 'preserve'
                source = 'current'
                workspaceId = $WorkspaceId
            })
        }
    }
    $installPlan.Add([pscustomobject]@{
        targetPath = '.pbbridge/project.json'
        action = if ($projectConfigChanged) { if (Test-Path -LiteralPath $existingProjectConfigPath -PathType Leaf) { 'replace' } else { 'create' } } else { 'no-op' }
        source = if ($projectConfigChanged) { 'generated' } else { 'current' }
        workspaceId = $WorkspaceId
    })
    $installPlan.Add([pscustomobject]@{
        targetPath = ".pbbridge/workspaces/$WorkspaceId/workspace.json"
        action = if ($workspaceConfigChanged) { if (Test-Path -LiteralPath $existingWorkspaceConfigPath -PathType Leaf) { 'replace' } else { 'create' } } else { 'no-op' }
        source = if ($workspaceConfigChanged) { 'generated' } else { 'current' }
        workspaceId = $WorkspaceId
    })
    $hasPlannedChanges = @($installPlan.ToArray() | Where-Object { $_.action -in @('create', 'replace') }).Count -gt 0

    $allWorkspaceIds = @($workspaceReferences.ToArray() | ForEach-Object { [string]$_.id } | Sort-Object -Unique)
    foreach ($request in $decisionRequests) {
        $request.workspaceIds = $allWorkspaceIds
        $request.decisionIdentityHash = Get-PbBridgeCanonicalHash -Value ([ordered]@{
            path = [string]$request.path
            classification = [string]$request.classification
            rawSha256 = [string]$request.rawSha256
            normalizedTextSha256 = [string]$request.normalizedTextSha256
            templateRawSha256 = [string]$request.templateRawSha256
            normalizationProfile = $script:NormalizationProfile
            policyHash = [string]$policy.policyHash
            provenanceRawSha256 = if ($null -ne $provenanceRegistryPath) { Get-PbBridgeSha256 -Path $provenanceRegistryPath } else { $null }
        })
    }
    foreach ($preserved in $preservedFiles) { $preserved.workspaceIds = $allWorkspaceIds }
    $publicMappings = @($fieldMappings.ToArray() | ForEach-Object {
        [ordered]@{
            file = $_.file
            parameter = $_.parameter
            configPath = $_.configPath
            value = $_.value
        }
    })
    $normalizedDecisionRequests = @(Sort-PbBridgeGovernancePathItems -Items $decisionRequests.ToArray() -Context 'plan-decision-requests')
    $semanticPlan = [ordered]@{
        productVersion = $script:ProductVersion
        workspaceId = $WorkspaceId
        workspaceIds = $allWorkspaceIds
        pbwPath = $PbwPath
        template = [ordered]@{
            templateVersion = [string]$manifest.templateVersion
            manifestRawSha256 = Get-PbBridgeSha256 -Path $templateManifestPath
            provenanceRawSha256 = if ($null -ne $provenanceRegistryPath) { Get-PbBridgeSha256 -Path $provenanceRegistryPath } else { $null }
        }
        policy = [ordered]@{
            path = '.pbbridge/migration-policy.json'
            exists = [bool]$policy.exists
            policyHash = [string]$policy.policyHash
            files = @($policy.files)
        }
        sourceConfiguration = [ordered]@{
            projectRawSha256 = if (Test-Path -LiteralPath $existingProjectConfigPath -PathType Leaf) { Get-PbBridgeSha256 -Path $existingProjectConfigPath } else { $null }
            workspaceRawSha256 = if (Test-Path -LiteralPath $existingWorkspaceConfigPath -PathType Leaf) { Get-PbBridgeSha256 -Path $existingWorkspaceConfigPath } else { $null }
        }
        configurationSha256 = $configurationSha256
        assets = @($assetClassifications.ToArray() | Sort-Object targetPath | ForEach-Object {
            [ordered]@{
                targetPath = $_.targetPath
                classification = $_.classification
                rawSha256 = $_.rawSha256
                normalizedTextSha256 = $_.normalizedTextSha256
                normalizationReasonCode = $_.normalizationReasonCode
                templateRawSha256 = $_.templateRawSha256
                templateNormalizedTextSha256 = $_.templateNormalizedTextSha256
                matchedTemplateVersion = $_.matchedTemplateVersion
                assetGroup = $_.assetGroup
            }
        })
        installPlan = @($installPlan.ToArray() | Sort-Object targetPath)
        decisionRequests = $normalizedDecisionRequests
        fieldMappings = $publicMappings
    }
    $computedPlanHash = Get-PbBridgeCanonicalHash -Value $semanticPlan
    if (-not [string]::IsNullOrWhiteSpace($PlanHash) -and $PlanHash -ne $computedPlanHash) {
        $manual.Add([pscustomobject]@{
            file = 'plan.json'
            code = 'migration-plan-stale'
            message = '当前源文件、目标模板、配置、policy 或 provenance 已与决定绑定计划不同；请重新 Plan。'
            line = $null
            column = $null
        })
    }

    $existingTransaction = Resolve-PbBridgeTransactionForPlan -MigrationRoot $migrationRoot -PlanHash $computedPlanHash
    if ($null -ne $existingTransaction) {
        $runId = $existingTransaction.migrationId
        $transactionRoot = $existingTransaction.transactionRoot
    }
    $stagingRoot = Join-Path $transactionRoot 'staging'
    $backupRoot = Join-Path $transactionRoot 'backup'
    $recoveryManifestPath = Join-Path $transactionRoot 'recovery-manifest.json'
    $candidateManifestPath = Join-Path $transactionRoot 'candidate-manifest.json'
    $planPath = Join-Path $transactionRoot 'plan.json'
    $decisionsPath = Join-Path $transactionRoot 'decisions.json'
    $auditResultPath = Join-Path $transactionRoot 'result.json'
    foreach ($file in $installFiles) { $file.stagingPath = Join-Path $stagingRoot $file.targetRelativePath }
    $applyWhatIfRequested = $Apply -and [bool]$WhatIfPreference
    if ($applyWhatIfRequested) {
        # 预检与不可变审计写入不是项目安装；避免 WhatIf 抑制证据目录后导致结果写入失败。
        $WhatIfPreference = $false
    }
    New-Item -ItemType Directory -Path $transactionRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $indexDocument = Save-PbBridgeMigrationIndex -MigrationRoot $migrationRoot -PlanHash $computedPlanHash -MigrationId $runId -TransactionRoot $transactionRoot
    Write-PbBridgeJsonFile -Path (Join-Path $transactionRoot 'index.json') -Value $indexDocument
    $planDocument = [ordered]@{
        schemaName = 'pbbridge-v7-template-migration-plan'
        schemaVersion = 8
        productVersion = $script:ProductVersion
        generatedAt = [DateTimeOffset]::UtcNow.ToString('O')
        migrationId = $runId
        planHash = $computedPlanHash
        policy = $semanticPlan.policy
        decisionRequests = $semanticPlan.decisionRequests
        semanticPlan = $semanticPlan
    }
    Write-PbBridgeJsonFile -Path $planPath -Value $planDocument

    $decisionSet = Import-PbBridgeReusableDecisions `
        -MigrationRoot $migrationRoot `
        -TransactionRoot $transactionRoot `
        -PlanHash $computedPlanHash `
        -DecisionRequests $normalizedDecisionRequests
    $validDecisionPaths = @($decisionSet.decisions | Where-Object { [string]$_.action -eq 'preserve-custom-and-continue' } | ForEach-Object { [string]$_.path })
    $awaitingDecisionCandidates = @($normalizedDecisionRequests | Where-Object {
        -not $_.policyDeclared -or [string]$_.path -notin $validDecisionPaths
    })
    $awaitingDecisions = $awaitingDecisionCandidates
    $policyMissingPaths = @($awaitingDecisions | Where-Object { -not [bool]$_.policyDeclared } | ForEach-Object { [string]$_.path })
    $decisionMissingPaths = @($awaitingDecisions | Where-Object { [bool]$_.policyDeclared } | ForEach-Object { [string]$_.path })
    $awaitingDecisionState = [ordered]@{
        kind = if ($policyMissingPaths.Count -gt 0 -and $decisionMissingPaths.Count -gt 0) {
            'policy-and-decision-missing'
        }
        elseif ($policyMissingPaths.Count -gt 0) {
            'policy-missing'
        }
        elseif ($decisionMissingPaths.Count -gt 0) {
            'decision-missing'
        }
        else {
            'none'
        }
        policyMissingPaths = $policyMissingPaths
        decisionMissingPaths = $decisionMissingPaths
    }
    if ($Apply -and
        $preservedFiles.Count -gt 0 -and
        $awaitingDecisions.Count -eq 0 -and
        [string]::IsNullOrWhiteSpace($PlanHash)) {
        $manual.Add([pscustomobject]@{
            file = 'plan.json'
            code = 'migration-plan-hash-required'
            message = '存在 preserved 决定时 Apply 必须显式绑定当前 -PlanHash；只有无人工决定的计划允许一次性 Plan+Apply。'
            line = $null
            column = $null
        })
    }
    $publicPreservedFiles = @($preservedFiles.ToArray() | Sort-Object targetPath | ForEach-Object {
        $preserved = $_
        $decision = @($decisionSet.decisions | Where-Object { [string]$_.path -eq [string]$preserved.targetPath }) | Select-Object -First 1
        [ordered]@{
            targetPath = $preserved.targetPath
            rawSha256 = $preserved.rawSha256
            classification = $preserved.classification
            workspaceIds = $preserved.workspaceIds
            installAction = 'preserve'
            decisionAction = if ($null -ne $decision) { [string]$decision.action } else { $null }
            decisionIdentityHash = if ($null -ne $decision) { [string]$decision.decisionIdentityHash } else { $null }
            decisionSetHash = $decisionSet.decisionSetHash
        }
    })

    $manifestSelectionSource = if ($null -ne $existingWorkspaceConfig -and
        -not [string]::IsNullOrWhiteSpace([string]$existingWorkspaceConfig.manifestPath)) {
        'configured-workspace-manifest'
    }
    elseif (Test-Path -LiteralPath (Join-Path $projectRootFull (".pbbridge\workspaces\{0}\artifacts\pbbridge\manifest.json" -f $WorkspaceId)) -PathType Leaf) {
        'existing-workspace-manifest'
    }
    else {
        'canonical-workspace-manifest'
    }

    $phase = if ($Apply) { 'apply' } else { 'plan' }
    $outcome = if ($manual.Count -gt 0) {
        'blocked'
    }
    elseif ($awaitingDecisions.Count -gt 0) {
        'awaiting-decisions'
    }
    elseif ($hasPlannedChanges) {
        'ready-to-apply'
    }
    else {
        'no-change'
    }
    $report = [ordered]@{
        schemaName = 'pbbridge-v7-template-migration'
        schemaVersion = 8
        productVersion = $script:ProductVersion
        generatedAt = [DateTimeOffset]::UtcNow.ToString('O')
        migrationId = $runId
        phase = $phase
        outcome = $outcome
        applyRequested = [bool]$Apply
        planHash = $computedPlanHash
        requestedPlanHash = if ([string]::IsNullOrWhiteSpace($PlanHash)) { $null } else { $PlanHash }
        decisionSetHash = $decisionSet.decisionSetHash
        decisions = @($decisionSet.decisions)
        awaitingDecisions = $awaitingDecisions
        awaitingDecisionState = $awaitingDecisionState
        projectRoot = $projectRootFull
        toolkitRoot = $toolkitRootFull
        workspaceId = $WorkspaceId
        manifestSelection = [ordered]@{
            source = $manifestSelectionSource
            path = [string]$workspaceConfig.manifestPath
            workspaceId = $WorkspaceId
        }
        provenance = [ordered]@{
            registryPath = $provenanceRegistryPath
            registryLoaded = $null -ne $provenanceRegistry
            registrySchemaVersion = if ($null -ne $provenanceRegistry) { [int]$provenanceRegistry.schemaVersion } else { $null }
            normalizationProfile = $script:NormalizationProfile
            classifications = $assetClassifications.ToArray()
        }
        policy = [ordered]@{
            path = $policy.path
            exists = $policy.exists
            policyHash = $policy.policyHash
            files = $policy.files
        }
        fieldMappings = $publicMappings
        manualMigrations = $manual.ToArray()
        installFiles = $plannedInstallFiles
        installPlan = $installPlan.ToArray()
        preservedFiles = $publicPreservedFiles
        compatibility = [ordered]@{ status = 'not-checked'; checks = @(); issues = @() }
        candidateSnapshot = [ordered]@{
            manifestPath = $candidateManifestPath
            snapshotSha256 = $null
            inputs = @()
        }
        config = [ordered]@{ project = $projectConfig; workspace = $workspaceConfig }
        configurationSha256 = $configurationSha256
        migrationVerdict = if ($manual.Count -gt 0) { 'blocked' } elseif ($awaitingDecisions.Count -gt 0) { 'awaiting-decisions' } elseif ($hasPlannedChanges) { 'changes-planned' } else { 'already-current' }
        audit = [ordered]@{
            planPath = $planPath
            decisionsPath = $decisionsPath
            resultPath = $auditResultPath
            indexPath = Join-Path $migrationRoot 'index.json'
        }
        transaction = [ordered]@{
            root = $transactionRoot
            stagingRoot = $stagingRoot
            backupRoot = $backupRoot
            recoveryManifestPath = $recoveryManifestPath
            candidateManifestPath = $candidateManifestPath
            candidateValidated = $false
            installedValidated = $false
            retentionDays = [int]$workspaceConfig.resultRetentionDays
            cleanupPolicy = 'retain-failed; remove-successful-staging-and-backup; prune-expired-results'
            cleanupStatus = 'not-started'
        }
        actualWrites = @()
        rollback = [ordered]@{ attempted = $false; succeeded = $null; errors = @(); restoredFiles = @() }
        failure = [ordered]@{ reasonCode = $null; detail = $null }
        wrapperSyntaxValid = $false
        wrapperSyntaxScope = 'none'
        nextAction = if ($manual.Count -gt 0) {
            '先处理阻断项并重新 Plan；旧决定不得复用。'
        }
        elseif ($awaitingDecisionState.kind -eq 'policy-and-decision-missing') {
            '先为 policyDeclared=false 的路径补充 .pbbridge/migration-policy.json 并重新 Plan；旧 planHash 已失效，再使用新 planHash 对仍待决定路径执行 Decide。'
        }
        elseif ($awaitingDecisionState.kind -eq 'policy-missing') {
            '为 policyDeclared=false 的路径补充 .pbbridge/migration-policy.json 并重新 Plan；随后使用 -Decide -PlanHash <hash> -DecisionPath <path> -Reason <reason>。'
        }
        elseif ($awaitingDecisionState.kind -eq 'decision-missing') {
            "policy 已声明；使用 -Decide -PlanHash $computedPlanHash -DecisionPath <path> -Reason <reason> 绑定当前计划，不需要再次补充 policy。"
        }
        elseif (-not $hasPlannedChanges) {
            "$script:ProductVersion 配置和受管资产已是当前状态，无需写入。"
        }
        elseif (-not $Apply) {
            New-PbBridgeTemplateMigrationApplyCommand `
                -ProjectRoot $projectRootFull `
                -ToolkitRoot $toolkitRootFull `
                -WorkspaceId $WorkspaceId `
                -PbwPath $PbwPath `
                -PlanHash $computedPlanHash
        }
        else {
            '执行绑定计划的事务安装与 preserved 兼容性验证。'
        }
    }

    if (-not $Apply -or $manual.Count -gt 0 -or $awaitingDecisions.Count -gt 0 -or (-not $hasPlannedChanges)) {
        Write-PbBridgeJsonFile -Path $auditResultPath -Value $report
        Write-PbBridgeJsonFile -Path $outputPathFull -Value $report
        return [pscustomobject]$report
    }

    $applyShouldProceed = $true
    if ($applyWhatIfRequested) {
        $WhatIfPreference = $true
        try {
            $applyShouldProceed = $PSCmdlet.ShouldProcess(
                $projectRootFull,
                "应用 workspace '$WorkspaceId' 的模板迁移计划 $computedPlanHash")
        }
        finally {
            $WhatIfPreference = $false
        }
    }
    else {
        $applyShouldProceed = $PSCmdlet.ShouldProcess(
            $projectRootFull,
            "应用 workspace '$WorkspaceId' 的模板迁移计划 $computedPlanHash")
    }
    if (-not $applyShouldProceed) {
        $report.phase = 'apply'
        $report.outcome = 'ready-to-apply'
        $report.migrationVerdict = 'changes-planned'
        $report.nextAction = New-PbBridgeTemplateMigrationApplyCommand `
            -ProjectRoot $projectRootFull `
            -ToolkitRoot $toolkitRootFull `
            -WorkspaceId $WorkspaceId `
            -PbwPath $PbwPath `
            -PlanHash $computedPlanHash
        Write-PbBridgeJsonFile -Path $auditResultPath -Value $report
        Write-PbBridgeJsonFile -Path $outputPathFull -Value $report
        return [pscustomobject]$report
    }

    $recoveryEntries = New-Object System.Collections.Generic.List[object]
    try {
        New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        foreach ($file in $installFiles) {
            $stagingParent = Split-Path -Parent $file.stagingPath
            if (-not (Test-Path -LiteralPath $stagingParent)) { New-Item -ItemType Directory -Path $stagingParent -Force | Out-Null }
            Copy-Item -LiteralPath $file.templatePath -Destination $file.stagingPath -Force
        }
        foreach ($preserved in $preservedFiles) {
            $preservedStagingPath = Join-Path $stagingRoot ([string]$preserved.targetPath)
            $preservedParent = Split-Path -Parent $preservedStagingPath
            if (-not (Test-Path -LiteralPath $preservedParent)) { New-Item -ItemType Directory -Path $preservedParent -Force | Out-Null }
            Copy-Item -LiteralPath $preserved.targetFullPath -Destination $preservedStagingPath -Force
            if ((Get-PbBridgeSha256 -Path $preservedStagingPath) -ne [string]$preserved.rawSha256) {
                throw "preserved-staging-hash-mismatch: $($preserved.targetPath)"
            }
        }

        $stagedProjectConfigPath = Join-Path $stagingRoot '.pbbridge\project.json'
        New-Item -ItemType Directory -Path (Split-Path -Parent $stagedProjectConfigPath) -Force | Out-Null
        if ($projectConfigChanged) {
            $projectConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $stagedProjectConfigPath -Encoding UTF8
            $installFiles.Add([pscustomobject]@{ templatePath = $null; targetPath = (Join-Path $projectRootFull '.pbbridge\project.json'); targetRelativePath = '.pbbridge/project.json'; stagingPath = $stagedProjectConfigPath })
        }
        else {
            Copy-Item -LiteralPath $existingProjectConfigPath -Destination $stagedProjectConfigPath -Force
        }

        $stagedWorkspaceConfigPath = Join-Path $stagingRoot (".pbbridge\workspaces\{0}\workspace.json" -f $WorkspaceId)
        New-Item -ItemType Directory -Path (Split-Path -Parent $stagedWorkspaceConfigPath) -Force | Out-Null
        if ($workspaceConfigChanged) {
            $workspaceConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $stagedWorkspaceConfigPath -Encoding UTF8
            $installFiles.Add([pscustomobject]@{ templatePath = $null; targetPath = (Join-Path $projectRootFull (".pbbridge\workspaces\{0}\workspace.json" -f $WorkspaceId)); targetRelativePath = ".pbbridge/workspaces/$WorkspaceId/workspace.json"; stagingPath = $stagedWorkspaceConfigPath })
        }
        else {
            Copy-Item -LiteralPath $existingWorkspaceConfigPath -Destination $stagedWorkspaceConfigPath -Force
        }

        $candidateInputs = New-Object System.Collections.Generic.List[object]
        foreach ($planEntry in @($installPlan.ToArray())) {
            $candidatePath = Join-Path $stagingRoot ([string]$planEntry.targetPath)
            if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
                throw "candidate-input-missing: $($planEntry.targetPath)"
            }
            $identity = if ([System.IO.Path]::GetExtension($candidatePath) -in @('.ps1', '.psm1')) { Get-PbBridgeTextIdentity -Path $candidatePath } else { $null }
            $candidateDecision = @($decisionSet.decisions | Where-Object { [string]$_.path -eq [string]$planEntry.targetPath }) | Select-Object -First 1
            $candidateInputs.Add([pscustomobject]@{
                targetPath = [string]$planEntry.targetPath
                workspaceId = $WorkspaceId
                workspaceIds = if ($null -ne $candidateDecision) { @($candidateDecision.workspaceIds) } else { @($WorkspaceId) }
                source = [string]$planEntry.source
                installAction = [string]$planEntry.action
                rawSha256 = Get-PbBridgeSha256 -Path $candidatePath
                normalizedTextSha256 = if ($null -ne $identity) { $identity.normalizedTextSha256 } else { $null }
                normalizationProfile = if ($null -ne $identity) { $identity.normalizationProfile } else { $null }
                decisionAction = if ($null -ne $candidateDecision) { [string]$candidateDecision.action } else { $null }
                decisionIdentityHash = if ($null -ne $candidateDecision) { [string]$candidateDecision.decisionIdentityHash } else { $null }
                decisionSetHash = if ($null -ne $candidateDecision) { $decisionSet.decisionSetHash } else { $null }
            })
        }
        $candidateManifest = [ordered]@{
            schemaName = 'pbbridge-v7-template-migration-candidate'
            schemaVersion = 8
            productVersion = $script:ProductVersion
            migrationId = $runId
            planHash = $computedPlanHash
            decisionSetHash = $decisionSet.decisionSetHash
            workspaceId = $WorkspaceId
            inputs = $candidateInputs.ToArray()
        }
        $candidateSnapshotSha256 = Get-PbBridgeTextSha256 -Text ($candidateManifest | ConvertTo-Json -Depth 10 -Compress)
        $candidateManifest.snapshotSha256 = $candidateSnapshotSha256
        Write-PbBridgeJsonFile -Path $candidateManifestPath -Value $candidateManifest
        $report.candidateSnapshot.snapshotSha256 = $candidateSnapshotSha256
        $report.candidateSnapshot.inputs = $candidateInputs.ToArray()

        if ($FailureInjection -eq 'candidate-syntax') {
            $candidatePath = @(Get-ChildItem -LiteralPath $stagingRoot -Recurse -File | Where-Object Extension -eq '.ps1') | Select-Object -First 1
            if ($null -ne $candidatePath) { Add-Content -LiteralPath $candidatePath.FullName -Value "`nparam(" -Encoding UTF8 }
        }
        if ($FailureInjection -eq 'candidate-identity') {
            $invalidWorkspaceConfig = Get-Content -LiteralPath $stagedWorkspaceConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $invalidWorkspaceConfig.id = 'wrong-workspace'
            $invalidWorkspaceConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $stagedWorkspaceConfigPath -Encoding UTF8
        }
        $candidateIssues = @(Test-PbBridgeCandidateTree `
            -StagingRoot $stagingRoot `
            -ProjectRoot $projectRootFull `
            -WorkspaceId $WorkspaceId `
            -TemplateManifestPath $templateManifestPath `
            -ToolkitRoot $toolkitRootFull `
            -PreservedRelativePath @($preservedFiles | ForEach-Object { [string]$_.targetPath }))
        if ($candidateIssues.Count -gt 0) {
            foreach ($issue in $candidateIssues) { $manual.Add($issue) }
            throw 'candidate-validation-failed'
        }
        $report.transaction.candidateValidated = $true
        $report.wrapperSyntaxValid = $true
        $report.wrapperSyntaxScope = 'candidate'
        $compatibility = Test-PbBridgePreservedCompatibility -StagingRoot $stagingRoot -PreservedEntries $preservedFiles.ToArray() -ToolkitRoot $toolkitRootFull
        $report.compatibility.checks = $compatibility.checks
        $report.compatibility.issues = $compatibility.issues
        $report.compatibility.status = if ($compatibility.issues.Count -eq 0) { 'clear' } else { 'blocked' }
        if ($compatibility.issues.Count -gt 0) {
            foreach ($issue in $compatibility.issues) { $manual.Add($issue) }
            throw 'blocked-incompatible-customization'
        }

        foreach ($file in $installFiles) {
            $target = Resolve-PbBridgePathInsideRoot -Root $projectRootFull -Path $file.targetPath -ReasonCode 'install-target-outside-project'
            $existed = Test-Path -LiteralPath $target -PathType Leaf
            $backupPath = Join-Path $backupRoot $file.targetRelativePath
            if ($existed) {
                New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
                Copy-Item -LiteralPath $target -Destination $backupPath -Force
            }
            $recoveryEntries.Add([pscustomobject]@{
                targetPath = $target
                targetRelativePath = [string]$file.targetRelativePath
                stagingPath = $file.stagingPath
                backupPath = $backupPath
                existed = $existed
                candidateSha256 = Get-PbBridgeSha256 -Path $file.stagingPath
                originalSha256 = if ($existed) { Get-PbBridgeSha256 -Path $target } else { $null }
            })
        }
        [ordered]@{
            schemaName = 'pbbridge-v7-template-migration-recovery'
            schemaVersion = 8
            productVersion = $script:ProductVersion
            migrationId = $runId
            planHash = $computedPlanHash
            entries = $recoveryEntries.ToArray()
        } | ForEach-Object { Write-PbBridgeJsonFile -Path $recoveryManifestPath -Value $_ }

        $commitIndex = 0
        foreach ($entry in $recoveryEntries) {
            $targetParent = Split-Path -Parent $entry.targetPath
            if (-not (Test-Path -LiteralPath $targetParent)) { New-Item -ItemType Directory -Path $targetParent -Force | Out-Null }
            $temporaryPath = Join-Path $targetParent ('.{0}.{1}.tmp' -f ([System.IO.Path]::GetFileName($entry.targetPath)), $runId)
            Copy-Item -LiteralPath $entry.stagingPath -Destination $temporaryPath -Force
            Move-Item -LiteralPath $temporaryPath -Destination $entry.targetPath -Force
            $commitIndex++
            $report.actualWrites = @($recoveryEntries | Select-Object -First $commitIndex | ForEach-Object {
                [ordered]@{
                    targetPath = [string]$_.targetRelativePath
                    beforeRawSha256 = $_.originalSha256
                    afterRawSha256 = $_.candidateSha256
                }
            })
            if ($FailureInjection -eq 'file-locked' -and $commitIndex -eq 1) { throw 'failure-injection-file-locked' }
        }

        if ($FailureInjection -eq 'write-truncated') {
            [System.IO.File]::WriteAllText($recoveryEntries[0].targetPath, 'truncated')
        }
        if ($FailureInjection -in @('post-install-hash', 'rollback-failure')) {
            Add-Content -LiteralPath $recoveryEntries[0].targetPath -Value "`n# hash drift" -Encoding UTF8
        }

        foreach ($entry in $recoveryEntries) {
            if ((Get-PbBridgeSha256 -Path $entry.targetPath) -ne $entry.candidateSha256) {
                throw "post-install-hash-mismatch: $($entry.targetPath)"
            }
        }
        foreach ($preserved in $preservedFiles) {
            if ((Get-PbBridgeSha256 -Path $preserved.targetFullPath) -ne [string]$preserved.rawSha256) {
                throw "post-install-preserved-hash-mismatch: $($preserved.targetPath)"
            }
        }
        $report.transaction.installedValidated = $true
        $report.wrapperSyntaxValid = $true
        $report.wrapperSyntaxScope = 'installed'
        $report.phase = 'completed'
        $report.outcome = if (-not $hasPlannedChanges) { 'no-change' } elseif ($preservedFiles.Count -gt 0) { 'applied-with-preserved-customizations' } else { 'applied' }
        $report.migrationVerdict = if ($hasPlannedChanges) { 'changes-applied' } else { 'already-current' }
        $report.nextAction = if ($hasPlannedChanges) {
                "$script:ProductVersion 配置、受管模板与 preserved 自定义文件已验证；重新生成 workspace facts 并执行 V8 preflight。"
        }
        else {
                "$script:ProductVersion 配置、受管模板和 preserved 自定义文件仍为当前且兼容；无需项目写入。"
        }
    }
    catch {
        $failureDetail = $_.Exception.Message
        $report.failure.reasonCode = if ($failureDetail -eq 'blocked-incompatible-customization') {
            'blocked-incompatible-customization'
        }
        elseif ($failureDetail -eq 'candidate-validation-failed' -or
            $failureDetail.StartsWith('candidate-input-missing:', [StringComparison]::Ordinal)) {
            'candidate-validation-failed'
        }
        elseif ($report.transaction.candidateValidated) {
            'post-install-validation-failed'
        }
        else {
            'candidate-validation-failed'
        }
        $report.failure.detail = $failureDetail
        $report.phase = 'completed'
        if ($failureDetail -eq 'blocked-incompatible-customization') {
            $report.rollback.attempted = $false
            $report.rollback.succeeded = $null
            $report.rollback.errors = @()
            $report.outcome = 'blocked-incompatible-customization'
            $report.migrationVerdict = 'blocked-incompatible-customization'
        }
        else {
            $report.rollback.attempted = $recoveryEntries.Count -gt 0
            $rollbackErrors = @(if ($FailureInjection -eq 'rollback-failure') {
                'failure-injection-rollback-failed: 按 recovery manifest 手工恢复全部写入路径。'
            }
            else {
                Restore-PbBridgeMigration -Entries $recoveryEntries.ToArray()
            })
            $report.rollback.errors = $rollbackErrors
            $report.rollback.succeeded = $rollbackErrors.Count -eq 0
            $report.rollback.restoredFiles = @($recoveryEntries | ForEach-Object {
                $existsAfterRecovery = Test-Path -LiteralPath $_.targetPath -PathType Leaf
                $restoredRawSha256 = if ($existsAfterRecovery) { Get-PbBridgeSha256 -Path $_.targetPath } else { $null }
                [ordered]@{
                    targetPath = [string]$_.targetRelativePath
                    expectedRawSha256 = $_.originalSha256
                    restoredRawSha256 = $restoredRawSha256
                    matchesOriginal = if ([bool]$_.existed) { $restoredRawSha256 -eq $_.originalSha256 } else { -not $existsAfterRecovery }
                }
            })
            $report.outcome = if ($rollbackErrors.Count -eq 0) { 'rolled-back' } else { 'recovery-required' }
            $report.migrationVerdict = if ($rollbackErrors.Count -eq 0) { 'failed-and-rolled-back' } else { 'recovery-required' }
        }
        $report.transaction.cleanupStatus = 'retained-after-failure'
        $report.nextAction = if ($report.outcome -eq 'recovery-required') {
            "事务安装及自动回滚失败：$failureDetail。立即按 recovery manifest 恢复记录的目标路径，核对 rawSha256 后再重新 Plan。"
        }
        else {
            "事务安装失败：$failureDetail。检查 recovery manifest 后重新运行 dry-run。"
        }
    }

    if ($report.outcome -in @('applied', 'applied-with-preserved-customizations', 'no-change')) {
        try {
            foreach ($ephemeralRoot in @($stagingRoot, $backupRoot)) {
                if (Test-Path -LiteralPath $ephemeralRoot) {
                    Remove-Item -LiteralPath $ephemeralRoot -Recurse -Force
                }
                New-Item -ItemType Directory -Path $ephemeralRoot -Force | Out-Null
            }
            $report.transaction.cleanupStatus = 'successful-audit-retained-ephemeral-content-removed'
        }
        catch {
            $report.transaction.cleanupStatus = 'successful-transaction-retained'
            $report.transaction.cleanupError = $_.Exception.Message
        }
    }

    $report.fieldMappings = $publicMappings
    $report.manualMigrations = $manual.ToArray()
    Write-PbBridgeJsonFile -Path $auditResultPath -Value $report
    Write-PbBridgeJsonFile -Path $outputPathFull -Value $report
    return [pscustomobject]$report
}

Export-ModuleMember -Function Invoke-PbBridgeTemplateMigration
