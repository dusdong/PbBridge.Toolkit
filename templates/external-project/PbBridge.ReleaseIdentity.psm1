#requires -PSEdition Core
#requires -Version 7.4
Set-StrictMode -Version Latest

function Assert-PbReleasePlainPath {
    # Check existing ancestors and descendants before any candidate write or executable load.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [switch]$Recurse, [Collections.Generic.HashSet[string]]$CheckedPaths)
    if (-not [IO.Path]::IsPathFullyQualified($Path)) { throw 'CANDIDATE_ABSOLUTE_PATH_REQUIRED' }
    $full = [IO.Path]::GetFullPath($Path)
    $current = $full
    while ($current) {
        if ($null -ne $CheckedPaths -and $CheckedPaths.Contains($current)) { break }
        if ((Test-Path -LiteralPath $current) -and
            ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'CANDIDATE_REPARSE_PATH' }
        $null = if ($null -ne $CheckedPaths) { $CheckedPaths.Add($current) }
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }; $current = $parent
    }
    if ($Recurse -and (Test-Path -LiteralPath $full -PathType Container)) {
        foreach ($item in Get-ChildItem -LiteralPath $full -Force -Recurse) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'CANDIDATE_REPARSE_PATH' }
        }
    }
    if ($full -eq [IO.Path]::GetPathRoot($full)) { throw 'CANDIDATE_PATH_CANNOT_BE_DRIVE_ROOT' }
    return $full.TrimEnd('\','/')
}

function Assert-PbReleaseInputInventory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$InventoryPath,
        [Parameter(Mandatory)][string]$InventorySha256, [Parameter(Mandatory)][string]$ProductVersion,
        [switch]$ExactFiles)
    $rootPath = Assert-PbReleasePlainPath -Path $Root -Recurse:$ExactFiles
    $null = Assert-PbReleasePlainPath $InventoryPath
    if ($InventorySha256 -cnotmatch '^[0-9a-f]{64}$' -or
        (Get-FileHash -LiteralPath $InventoryPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $InventorySha256) { throw 'CANDIDATE_INVENTORY_DRIFTED' }
    $inventory = Get-Content -LiteralPath $InventoryPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 50
    if ([string]$inventory.productVersion -cne $ProductVersion -or @($inventory.files).Count -eq 0) { throw 'CANDIDATE_INVENTORY_INVALID' }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $checkedPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $inventory.files) {
        $relative = [string]$entry.path
        if (-not $relative -or [IO.Path]::IsPathRooted($relative) -or $relative -match '(^|/)\.\.?(/|$)|[\\:*?\x00-\x1f]' -or -not $seen.Add($relative)) { throw 'CANDIDATE_INVENTORY_PATH_INVALID' }
        $path = Join-Path $rootPath $relative
        $null = Assert-PbReleasePlainPath -Path $path -CheckedPaths $checkedPaths
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or [string]$entry.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
            (Get-Item -LiteralPath $path).Length -ne [long]$entry.length -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$entry.sha256) { throw "CANDIDATE_INPUT_DRIFTED:$relative" }
    }
    if ($ExactFiles) {
        $files = @(Get-ChildItem -LiteralPath $rootPath -File -Recurse -Force)
        if ($files.Count -ne $seen.Count) { throw 'CANDIDATE_INPUT_INVENTORY_NOT_CLOSED' }
        foreach ($file in $files) {
            if (-not $seen.Contains([IO.Path]::GetRelativePath($rootPath,$file.FullName).Replace('\','/'))) { throw 'CANDIDATE_INPUT_INVENTORY_NOT_CLOSED' }
        }
    }
    return $inventory
}

function Get-PbCandidateRuntimeBinaryFact {
    # Pure binary inspection: no assembly load into the runtime and no application launch.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RuntimeRoot,[Parameter(Mandatory)][string]$ExpectedProductVersion)
    $facts=[Collections.Generic.List[object]]::new()
    foreach ($pair in @(@('cli/win-x86/PbBridge.Cli.exe',332),@('ide/win-x64/SharpIDE.exe',34404),@('pbspy/win-x86/PBSpy.dll',332))) {
        $path=Join-Path $RuntimeRoot $pair[0]
        $stream=[IO.File]::OpenRead($path);$reader=[IO.BinaryReader]::new($stream)
        try {
            if ($stream.Length -lt 64 -or $reader.ReadUInt16() -ne 23117) { throw 'CANDIDATE_PE_HEADER_INVALID' }
            $stream.Position=60;$offset=$reader.ReadInt32()
            if ($offset -lt 64 -or $offset -gt $stream.Length-6) { throw 'CANDIDATE_PE_HEADER_INVALID' }
            $stream.Position=$offset
            if ($reader.ReadUInt32() -ne 17744 -or $reader.ReadUInt16() -ne $pair[1]) { throw "CANDIDATE_PE_MACHINE_INVALID:$($pair[0])" }
        } finally {$reader.Dispose();$stream.Dispose()}
        $facts.Add([pscustomobject]@{path=$pair[0];machine=$pair[1];sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant();productVersion=[Diagnostics.FileVersionInfo]::GetVersionInfo($path).ProductVersion})
    }
    foreach ($name in @('PbBridge.Core','PbBridge.Adapter.PB9','PbBridge.Delivery','PbBridge.SharpIDE.Extension','PbBridge.SharpIDE.Host')) {
        $relative='ide/win-x64/data_PbBridge.SharpIDE.Host_windows_x86_64/'+$name+'.dll'
        $path=Join-Path $RuntimeRoot $relative
        $version=[Reflection.AssemblyName]::GetAssemblyName($path).Version.ToString()
        if ($version -cne ($ExpectedProductVersion+'.0')) { throw "CANDIDATE_ASSEMBLY_VERSION_MISMATCH:$name" }
        $facts.Add([pscustomobject]@{path=$relative;assemblyVersion=$version;sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()})
    }
    return $facts.ToArray()
}

function Get-PbReleaseFileIdentity {
    <# .SYNOPSIS Returns the actual bytes identity of a file without modifying it. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LiteralPath)
    $file=Get-Item -LiteralPath $LiteralPath -ErrorAction Stop
    [pscustomobject]@{path=$file.FullName;length=$file.Length;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
}

function Write-PbReleaseFrozenFile {
    <# .SYNOPSIS Creates immutable bytes once; identical existing bytes are verified read-only. #>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$LiteralPath,[Parameter(Mandatory)][byte[]]$Bytes)
    $expected=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
    if (Test-Path -LiteralPath $LiteralPath) {
        $actual=Get-PbReleaseFileIdentity $LiteralPath
        if($actual.length -ne $Bytes.Length -or $actual.sha256 -cne $expected){throw 'RELEASE_FROZEN_PATH_OCCUPIED'}
        return [pscustomobject]@{status='already-identical';file=$actual;written=$false}
    }
    if($PSCmdlet.ShouldProcess($LiteralPath,'Create immutable release file')) {
        $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($LiteralPath)))
        $stream=[IO.File]::Open($LiteralPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try {$stream.Write($Bytes);$stream.Flush($true)} finally {$stream.Dispose()}
        return [pscustomobject]@{status='created';file=(Get-PbReleaseFileIdentity $LiteralPath);written=$true}
    }
}

function Assert-PbReleaseFrozenReference {
    <# .SYNOPSIS Rejects missing or drifted frozen files, including length mismatches. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LiteralPath,[Parameter(Mandatory)][object]$Reference)
    $actual=Get-PbReleaseFileIdentity $LiteralPath
    $hasLength=if($Reference -is [Collections.IDictionary]){$Reference.Contains('length')}else{$null -ne $Reference.PSObject.Properties['length']}
    if(-not $hasLength -or [string]$Reference.sha256 -cnotmatch '^[0-9a-f]{64}$' -or $actual.sha256 -cne [string]$Reference.sha256 -or
        $actual.length -ne [long]$Reference.length){throw 'RELEASE_FROZEN_REFERENCE_DRIFTED'}
    $actual
}

function New-PbReleasePublicationReceipt {
    <# .SYNOPSIS Adds a separate publication receipt; never updates a frozen record. #>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$RecordPath,[Parameter(Mandatory)][object]$RecordReference,
        [Parameter(Mandatory)][string]$OutputPath,[Parameter(Mandatory)][string]$PublishedCommit,
        [Parameter(Mandatory)][string]$PublicationEvidencePath)
    if([IO.Path]::GetFullPath($RecordPath) -eq [IO.Path]::GetFullPath($OutputPath)){throw 'RELEASE_RECORD_SELF_REFERENCE'}
    $actual=Assert-PbReleaseFrozenReference $RecordPath $RecordReference
    $record=Get-Content -LiteralPath $RecordPath -Raw -Encoding utf8|ConvertFrom-Json
    if($PublishedCommit -cnotmatch '^[0-9a-f]{40}$' -or $PublishedCommit -cne [string]$record.candidate.repository.commit){throw 'RELEASE_PUBLICATION_COMMIT_MISMATCH'}
    if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($PublicationEvidencePath)) -cne [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($OutputPath)) -or
        [IO.Path]::GetFileName($PublicationEvidencePath) -cne 'manifest-finalization.json') { throw 'RELEASE_PUBLICATION_EVIDENCE_LOCATION_INVALID' }
    $proofReference=Get-PbReleaseFileIdentity $PublicationEvidencePath
    $proof=Get-Content -LiteralPath $PublicationEvidencePath -Raw -Encoding utf8|ConvertFrom-Json -Depth 100
    Assert-PbReleasePublicationEvidence -RecordPath $RecordPath -Record $record -Evidence $proof
    $receipt=[ordered]@{schemaName='pbbridge-release-publication-receipt';schemaVersion=1;productVersion=$record.productVersion;publishedCommit=$PublishedCommit;frozenRecord=$actual;candidate=$record.candidate;
        publicationEvidence=@{path='manifest-finalization.json';length=$proofReference.length;sha256=$proofReference.sha256};publishedAt=[DateTimeOffset]::UtcNow.ToString('O')}
    if(Test-Path -LiteralPath $OutputPath){throw 'RELEASE_PUBLICATION_RECEIPT_EXISTS'}
    if($PSCmdlet.ShouldProcess($OutputPath,'Create publication receipt')){
        Write-PbReleaseFrozenFile -LiteralPath $OutputPath -Bytes ([Text.UTF8Encoding]::new($false).GetBytes(($receipt|ConvertTo-Json -Depth 20)))
    }
}

function Assert-PbReleasePublicationEvidence {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RecordPath,[Parameter(Mandatory)][object]$Record,[Parameter(Mandatory)][object]$Evidence)
    Assert-PbPublishedRecordIdentity -Record $Record
    $commit=[string]$Record.candidate.repository.commit
    if ([string]$Evidence.schemaName -cne 'pbbridge-v7-manifest-finalization' -or [int]$Evidence.schemaVersion -ne 1 -or
        [string]$Evidence.status -cne 'passed' -or [string]$Evidence.lifecycleState -cne 'finalized' -or
        [string]$Evidence.productVersion -cne [string]$Record.productVersion -or
        [string]$Evidence.tag -cne "v$($Record.productVersion)" -or [string]$Evidence.tagCommit -cne $commit -or
        [string]$Evidence.tagObject -cnotmatch '^[0-9a-f]{40}$' -or
        [string]$Evidence.tagGuard.status -cne 'clear' -or [string]$Evidence.tagGuard.localTagCommit -cne $commit -or
        [string]$Evidence.tagGuard.remoteTagCommit -cne $commit -or
        [string]$Evidence.artifactValidation.status -cne 'passed' -or [string]$Evidence.finalConsistency.status -cne 'passed' -or
        @($Evidence.reasons).Count -ne 0 -or
        (($Evidence.candidate|ConvertTo-Json -Depth 100 -Compress) -cne ($Record.candidate|ConvertTo-Json -Depth 100 -Compress))) {
        throw 'RELEASE_PUBLICATION_EVIDENCE_INVALID'
    }
    $null=Assert-PbReleaseFrozenReference $RecordPath $Evidence.replacementReleaseRecord
}

function Assert-PbPublishedRecordIdentity {
    param([Parameter(Mandatory)][object]$Record)
    $candidate=$Record.candidate
    if ([string]$Record.schemaName -cne 'pbbridge-replacement-release-record' -or [int]$Record.recordVersion -ne 3 -or
        [string]$Record.productVersion -cnotmatch '^\d+\.\d+\.\d+$' -or
        [string]$candidate.buildIdentity.productVersion -cne [string]$Record.productVersion -or
        [string]$candidate.toolkit.commit -cnotmatch '^[0-9a-f]{40}$' -or [string]$candidate.repository.commit -cnotmatch '^[0-9a-f]{40}$') { throw 'RELEASE_PUBLISHED_IDENTITY_INVALID' }
    foreach($field in @('cliSha256','manifestSha256','runtimeContractSha256')) {
        if ([string]$candidate.buildIdentity.$field -cnotmatch '^[0-9a-f]{64}$') { throw 'RELEASE_PUBLISHED_IDENTITY_INVALID' }
    }
    if (($candidate.toolkit.PSObject.Properties['version'] -and [string]$candidate.toolkit.version -cne [string]$Record.productVersion) -or
        ($candidate.buildIdentity.PSObject.Properties['toolkitCommit'] -and [string]$candidate.buildIdentity.toolkitCommit -cne [string]$candidate.toolkit.commit)) { throw 'RELEASE_PUBLISHED_IDENTITY_INVALID' }
}

function Get-PbPublishedReleaseFact {
    <# .SYNOPSIS Resolves one published product from immutable record plus independently frozen publication evidence. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RecordPath,[string]$PublicationReceiptPath,[string]$ExpectedProductVersion,
        [ValidateSet('CompleteQualification','HistoricalRecovery')][string]$Purpose='CompleteQualification',[string]$ArtifactRoot)
    $record=Get-Content -LiteralPath $RecordPath -Raw -Encoding utf8|ConvertFrom-Json -Depth 100
    Assert-PbPublishedRecordIdentity -Record $record
    $version=[string]$record.productVersion;$candidate=$record.candidate
    if ($ExpectedProductVersion -and $version -cne $ExpectedProductVersion) { throw 'RELEASE_PUBLISHED_IDENTITY_INVALID' }
    $receiptReference=$null;$proofReference=$null
    if ($Purpose -ceq 'HistoricalRecovery') {
        if ($version -cne '7.5.3' -or -not $PublicationReceiptPath -or -not $ArtifactRoot) { throw 'SCOPED_PUBLICATION_PURPOSE_INVALID' }
        return Get-PbScoped753PublicationFact -RecordPath $RecordPath -PublicationReceiptPath $PublicationReceiptPath -ArtifactRoot $ArtifactRoot -Record $record
    }
    if ($PublicationReceiptPath) {
        $receipt=Get-Content -LiteralPath $PublicationReceiptPath -Raw -Encoding utf8|ConvertFrom-Json -Depth 100
        if ([string]$receipt.schemaName -cne 'pbbridge-release-publication-receipt' -or [int]$receipt.schemaVersion -ne 1 -or
            [string]$receipt.productVersion -cne $version -or [string]$receipt.publishedCommit -cne [string]$candidate.repository.commit -or
            (($receipt.candidate|ConvertTo-Json -Depth 100 -Compress) -cne ($candidate|ConvertTo-Json -Depth 100 -Compress)) -or
            [string]$receipt.publicationEvidence.path -cne 'manifest-finalization.json') { throw 'RELEASE_PUBLICATION_RECEIPT_MISMATCH' }
        $null=Assert-PbReleaseFrozenReference $RecordPath $receipt.frozenRecord
        $proofPath=Join-Path (Split-Path -Parent ([IO.Path]::GetFullPath($PublicationReceiptPath))) 'manifest-finalization.json'
        $proofReference=Assert-PbReleaseFrozenReference $proofPath $receipt.publicationEvidence
        $proof=Get-Content -LiteralPath $proofPath -Raw -Encoding utf8|ConvertFrom-Json -Depth 100
        Assert-PbReleasePublicationEvidence -RecordPath $RecordPath -Record $record -Evidence $proof
        $receiptReference=Get-PbReleaseFileIdentity $PublicationReceiptPath
        # Published projection only: the pre-tag record bytes remain untouched.
        $candidate=$candidate|ConvertTo-Json -Depth 100|ConvertFrom-Json -Depth 100
        $candidate.repository|Add-Member -NotePropertyName tagStatus -NotePropertyValue verified -Force
        $candidate.repository|Add-Member -NotePropertyName tagObject -NotePropertyValue ([string]$proof.tagObject) -Force
        $candidate.repository|Add-Member -NotePropertyName peeledCommit -NotePropertyValue ([string]$proof.tagCommit) -Force
    } elseif ([version]$version -ge [version]'7.5.3' -or [string]$record.status -cne 'ready' -or -not [bool]$record.cutoverAuthorized -or
        [string]$candidate.repository.tagStatus -cne 'verified' -or [string]$record.remoteArtifacts.status -notin @('verified','skipped-by-user') -or
        [string]$record.humanGate.status -cne 'accepted') { throw 'RELEASE_PUBLISHED_RECEIPT_REQUIRED' }
    [pscustomobject]@{record=$record;candidate=$candidate;recordReference=(Get-PbReleaseFileIdentity $RecordPath);receiptReference=$receiptReference;publicationEvidenceReference=$proofReference;published=$true}
}

function Get-PbToolkitSnapshotIdentity {
    <# .SYNOPSIS Computes full identity from actual Git blob bytes, with the actual snapshot commit outside its tree. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ToolkitPath,[Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$Commit)
    function Read-SnapshotBlob([string]$Path) {
        $info=[Diagnostics.ProcessStartInfo]::new('git')
        $info.UseShellExecute=$false;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
        foreach($arg in @('-C',$ToolkitPath,'cat-file','blob',"${Commit}:$Path")){$info.ArgumentList.Add($arg)}
        $process=[Diagnostics.Process]::Start($info)
        $errorTask=$process.StandardError.ReadToEndAsync()
        $bytes=[IO.MemoryStream]::new()
        try {
            $process.StandardOutput.BaseStream.CopyTo($bytes);$process.WaitForExit();$null=$errorTask.GetAwaiter().GetResult()
            if($process.ExitCode -ne 0){throw "SNAPSHOT_BLOB_UNAVAILABLE:$Path"}
            return ,$bytes.ToArray()
        } finally {$bytes.Dispose();$process.Dispose()}
    }
    $manifestBytes=Read-SnapshotBlob 'manifest.json'
    $runtimeBytes=Read-SnapshotBlob 'checks/toolkit-runtime-contract.json'
    $cliBytes=Read-SnapshotBlob 'runtime/cli/win-x86/PbBridge.Cli.exe'
    $manifestText=[Text.Encoding]::UTF8.GetString($manifestBytes)
    $runtimeText=[Text.Encoding]::UTF8.GetString($runtimeBytes)
    $manifest=$manifestText|ConvertFrom-Json;$runtime=$runtimeText|ConvertFrom-Json
    if($manifestText -match '"manifestSha256"\s*:' -or $runtimeText -match '"runtimeContractSha256"\s*:' -or
        $manifestText.Contains($Commit) -or $runtimeText.Contains($Commit)){throw 'SNAPSHOT_IDENTITY_SELF_REFERENCE'}
    $version=([Text.Encoding]::UTF8.GetString((Read-SnapshotBlob 'VERSION'))).Trim()
    foreach($actual in @($manifest.productVersion,$manifest.toolkitVersion,$runtime.toolkitVersion,$runtime.cliDoctorContractVersion)){
        if([string]$actual -cne $version){throw 'SNAPSHOT_VERSION_MISMATCH'}
    }
    $cliHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($cliBytes)).ToLowerInvariant()
    $pointer=[Text.Encoding]::UTF8.GetString($cliBytes)
    if ($pointer -cmatch '\Aversion https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n?\z') { $cliHash=$Matches[1] }
    $identity=[ordered]@{productVersion=$version;cliSha256=$cliHash;
        toolkitCommit=$Commit;manifestSha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($manifestBytes)).ToLowerInvariant();
        runtimeContractSha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($runtimeBytes)).ToLowerInvariant()}
    $checksums=[Text.Encoding]::UTF8.GetString((Read-SnapshotBlob 'checks/SHA256SUMS.txt'))
    if($checksums -match '(?m)^[0-9a-f]{64}\s+checks/SHA256SUMS\.txt\s*$'){throw 'SNAPSHOT_CHECKSUM_SELF_REFERENCE'}
    foreach($pair in @(@('manifest.json','manifestSha256'),@('checks/toolkit-runtime-contract.json','runtimeContractSha256'),@('runtime/cli/win-x86/PbBridge.Cli.exe','cliSha256'))){
        $pattern='(?m)^'+[regex]::Escape($identity[$pair[1]])+'\s{2}'+[regex]::Escape($pair[0])+'\r?$'
        if($checksums -cnotmatch $pattern){throw "SNAPSHOT_CHECKSUM_MISMATCH:$($pair[0])"}
    }
    [pscustomobject]@{identity=[pscustomobject]$identity;displayIdentity="$version / build $($identity.cliSha256.Substring(0,12)) / toolkit $Commit"}
}

function Resolve-PbReleaseRecoveryArchiveReference {
    # The caller supplies the fact returned by the published-product reader.
    # Only the original legacy 7.5.2 path may lack an archive length. Never add
    # the observed length to the frozen record or weaken the general validator.
    param([Parameter(Mandatory)][object]$Published,[Parameter(Mandatory)][object]$Entry,
        [Parameter(Mandatory)][string]$Archive,[string]$PublicationReceiptPath)
    $hasLength=if($Entry -is [Collections.IDictionary]){$Entry.Contains('length')}else{$null -ne $Entry.PSObject.Properties['length']}
    $legacyLengthObserved=-not $hasLength -and -not $PublicationReceiptPath -and
        [string]$Published.record.productVersion -ceq '7.5.2' -and $Published.published -eq $true
    $reference=$Entry
    if($legacyLengthObserved){
        $reference=[pscustomobject]@{sha256=[string]$Entry.sha256;length=(Get-Item -LiteralPath $Archive -ErrorAction Stop).Length}
    }
    $actual=Assert-PbReleaseFrozenReference -LiteralPath $Archive -Reference $reference
    [pscustomobject]@{artifact=$actual;lengthSource=if($legacyLengthObserved){'legacy-7.5.2-observed-original-artifact'}else{'frozen-reference'}}
}

function Get-PbReleaseRecoveryPreview {
    <#
    .SYNOPSIS Verifies original local archive bytes and the frozen five-part identity.
    .DESCRIPTION Missing, rebuilt, drifted or incomplete recovery materials fail closed.
    Only an explicit new isolation directory is extracted; business files are never restored.
    .PARAMETER RecordPath Tree-external frozen release record.
    .PARAMETER ArtifactRoot Explicit local archive channel containing record-relative artifacts.
    .PARAMETER ExtractionRoot New isolated extraction directory, never a consumer workspace.
    .EXAMPLE Get-PbReleaseRecoveryPreview -RecordPath record.json -ArtifactRoot archive -ExtractionRoot new-preview
    .OUTPUTS PSCustomObject with recovery status and full identity.
    .NOTES A successful result proves toolkit recovery only, not PBL or session recovery.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RecordPath,[Parameter(Mandatory)][string]$ArtifactRoot,
        [Parameter(Mandatory)][string]$ExtractionRoot,[string]$PublicationReceiptPath,
        [ValidateSet('CompleteQualification','HistoricalRecovery')][string]$Purpose='CompleteQualification')
    $identity=$null;$archive=$null
    try {
        $record=Get-Content -LiteralPath $RecordPath -Raw -Encoding utf8|ConvertFrom-Json
        if([string]$record.schemaName -cne 'pbbridge-replacement-release-record' -or [int]$record.recordVersion -ne 3){throw 'recovery-record-unsupported'}
        $published=Get-PbPublishedReleaseFact -RecordPath $RecordPath -PublicationReceiptPath $PublicationReceiptPath -Purpose $Purpose -ArtifactRoot $ArtifactRoot
        $candidate=$published.candidate
        $identity=[ordered]@{productVersion=[string]$candidate.buildIdentity.productVersion;cliSha256=[string]$candidate.buildIdentity.cliSha256;
            toolkitCommit=[string]$candidate.toolkit.commit;runtimeContractSha256=[string]$candidate.buildIdentity.runtimeContractSha256;manifestSha256=[string]$candidate.buildIdentity.manifestSha256}
        if($identity.productVersion -cnotmatch '^\d+\.\d+\.\d+$' -or $identity.productVersion -cne [string]$record.productVersion -or $identity.toolkitCommit -cnotmatch '^[0-9a-f]{40}$'){throw 'recovery-identity-incomplete'}
        foreach($field in @('cliSha256','runtimeContractSha256','manifestSha256')) {if($identity[$field] -cnotmatch '^[0-9a-f]{64}$'){throw 'recovery-identity-incomplete'}}
        $entries=@($candidate.releaseArtifacts|Where-Object {[string]$_.path -match '(?i)toolkit[^/]*\.zip$'})
        if($entries.Count -ne 1){throw 'recovery-original-artifact-unavailable'}
        $entry=$entries[0];$relative=[string]$entry.path
        if([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|/)\.\.?(/|$)|[\\:*?\x00-\x1f]'){throw 'recovery-artifact-path-invalid'}
        $archiveRoot=[IO.Path]::GetFullPath($ArtifactRoot).TrimEnd('\','/')
        $archive=[IO.Path]::GetFullPath((Join-Path $archiveRoot $relative))
        if(-not $archive.StartsWith($archiveRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'recovery-artifact-path-invalid'}
        $archiveVerification=Resolve-PbReleaseRecoveryArchiveReference -Published $published -Entry $entry -Archive $archive -PublicationReceiptPath $PublicationReceiptPath
        $extraction=[IO.Path]::GetFullPath($ExtractionRoot)
        if ($Purpose -ceq 'HistoricalRecovery') {
                $null=Assert-PbReleasePlainPath $ExtractionRoot
        }
        if(Test-Path -LiteralPath $extraction){throw 'recovery-isolation-path-occupied'}
        # Validate all zip entries before extracting; do not permit zip-slip or links.
        $zip=[IO.Compression.ZipFile]::OpenRead($archive)
        try {
            foreach($item in $zip.Entries){
                $target=[IO.Path]::GetFullPath((Join-Path $extraction $item.FullName))
                if(-not $target.StartsWith($extraction.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or
                    (($item.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000){throw 'recovery-archive-entry-invalid'}
            }
        } finally {$zip.Dispose()}
        [IO.Compression.ZipFile]::ExtractToDirectory($archive,$extraction)
        $roots=@($extraction,(Join-Path $extraction 'PbBridge.Toolkit'))
        $toolkit=@($roots|Where-Object {Test-Path -LiteralPath (Join-Path $_ 'manifest.json') -PathType Leaf})
        if($toolkit.Count -ne 1){throw 'recovery-toolkit-root-invalid'}
        $toolkit=$toolkit[0]
        foreach($pair in @(@('manifest.json','manifestSha256'),@('checks/toolkit-runtime-contract.json','runtimeContractSha256'),@('runtime/cli/win-x86/PbBridge.Cli.exe','cliSha256'))){
            if((Get-PbReleaseFileIdentity (Join-Path $toolkit $pair[0])).sha256 -cne $identity[$pair[1]]){throw "recovery-identity-mismatch:$($pair[1])"}
        }
        $recoveredChecksums=0
        if ($Purpose -ceq 'HistoricalRecovery') {
            $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($line in Get-Content -LiteralPath (Join-Path $toolkit 'checks/SHA256SUMS.txt') -Encoding utf8) {
                if (-not $line) { continue }
                if ($line -cnotmatch '^([0-9a-f]{64})  (.+)$') { throw 'recovery-checksum-invalid' }
                $hash=$Matches[1];$relative=$Matches[2]
                if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|/)\.\.?(/|$)|[\\:*?\x00-\x1f]' -or $relative -ceq 'checks/SHA256SUMS.txt' -or -not $seen.Add($relative)) { throw 'recovery-checksum-path-invalid' }
                if ((Get-PbReleaseFileIdentity (Join-Path $toolkit $relative)).sha256 -cne $hash) { throw "recovery-checksum-mismatch:$relative" }
            }
            foreach ($required in @('manifest.json','checks/toolkit-runtime-contract.json','runtime/cli/win-x86/PbBridge.Cli.exe')) {
                if (-not $seen.Contains($required)) { throw 'recovery-checksum-identity-missing' }
            }
            $recoveredChecksums=$seen.Count
        }
        $cli=Join-Path $toolkit 'runtime/cli/win-x86/PbBridge.Cli.exe'
        $versionOutput=& $cli version
        if($LASTEXITCODE -ne 0 -or [string](($versionOutput -join "`n"|ConvertFrom-Json).version) -cne $identity.productVersion){throw 'recovery-entrypoint-failed'}
        $doctorOutput=& $cli doctor
        if($LASTEXITCODE -ne 0){throw 'recovery-doctor-failed'}
        [pscustomobject]@{status='verified';reasonCode=$null;identity=$identity;artifact=$archiveVerification.artifact;artifactLengthSource=$archiveVerification.lengthSource;extractedToolkit=$toolkit;
            publicationScope=if($Purpose -ceq 'HistoricalRecovery'){$published.publicationScope}else{'complete-publication-contract'};fullQualification=if($Purpose -ceq 'HistoricalRecovery'){'not-completed'}else{'not-evaluated-by-recovery'};authorizationTransferable=$false;
            entrypoint=$cli;doctorOutput=($doctorOutput -join "`n");recoveryScope='toolkit-only';checksumsVerified=$recoveredChecksums;requiresCurrentFacts=$true;businessRestored=$false}
    } catch {
        [pscustomobject]@{status='unavailable';reasonCode=$_.Exception.Message;identity=$identity;artifactPath=$archive;
            recoveryScope='toolkit-only';requiresCurrentFacts=$true;businessRestored=$false}
    }
}


function Get-PbCandidatePreservedInput {
    <# .SYNOPSIS Validates explicit retained bytes before candidate generation. #>
    [CmdletBinding()]
    param([string]$Root,[string]$InventoryPath,[string]$InventorySha256,
        [Parameter(Mandatory)][string]$OutputRoot,[Parameter(Mandatory)][string]$ProductVersion)
    if (-not $Root -and -not $InventoryPath -and -not $InventorySha256) { return $null }
    if (-not $Root -or -not $InventoryPath -or -not $InventorySha256) { throw 'CANDIDATE_PRESERVED_PARAMETERS_INCOMPLETE' }
    $inputRoot=Assert-PbReleasePlainPath -Path $Root -Recurse
    $output=Assert-PbReleasePlainPath -Path $OutputRoot
    if ($inputRoot -eq $output -or $inputRoot.StartsWith($output+'\',[StringComparison]::OrdinalIgnoreCase) -or
        $output.StartsWith($inputRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'CANDIDATE_PRESERVED_OUTPUT_OVERLAP' }
    $inventory=Assert-PbReleaseInputInventory -Root $inputRoot -InventoryPath $InventoryPath -InventorySha256 $InventorySha256 -ProductVersion $ProductVersion -ExactFiles
    foreach ($entry in $inventory.files) {
        # Management data, current metadata, and symbols never become retained distribution inputs.
        if ([string]$entry.path -cnotmatch '^(runtime|docs|skills|syntax)/' -or
            [string]$entry.path -match '(^|/)\.git(?:/|$)|\.pdb$') { throw 'CANDIDATE_PRESERVED_PATH_FORBIDDEN' }
    }
    return $inventory
}

function Assert-PbToolkitSnapshotFiles {
    <# .SYNOPSIS Matches the complete candidate against every actual Git blob, without filters or writes. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ToolkitPath,[Parameter(Mandatory)][string]$RepositoryPath,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$Commit,[Parameter(Mandatory)][object[]]$Files,
        [switch]$RestoredLfs)
    $null=Assert-PbReleasePlainPath -Path $RepositoryPath
    $head=@(& git -C $RepositoryPath rev-parse HEAD 2>$null) -join ''
    if ($LASTEXITCODE -ne 0 -or $head.Trim() -cne $Commit) { throw 'CANDIDATE_SNAPSHOT_HEAD_MISMATCH' }
    # ls-tree -z names are UTF-8 bytes. Console encoding varies when this entry
    # is called with redirected output; never decode Git paths through it.
    $previousConsoleEncoding=[Console]::OutputEncoding
    try {
        [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
        $tree=@(& git -c core.quotepath=false -C $RepositoryPath ls-tree --full-tree -r -z $Commit 2>$null) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw 'CANDIDATE_SNAPSHOT_UNAVAILABLE' }
    } finally { [Console]::OutputEncoding=$previousConsoleEncoding }
    $entries=[Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($entry in $tree.Split([char]0,[StringSplitOptions]::RemoveEmptyEntries)) {
        if ($entry -cnotmatch '^(100644|100755) blob ([0-9a-f]{40})\t(.+)$' -or $entries.ContainsKey($Matches[3])) { throw 'CANDIDATE_SNAPSHOT_TREE_INVALID' }
        $entries.Add($Matches[3],$Matches[2])
    }
    if ($entries.Count -ne $Files.Count) { throw 'CANDIDATE_SNAPSHOT_FILE_SET_MISMATCH' }
    $lfsEntries=@{}
    if ($RestoredLfs) {
        $listing=(@(& git -C $RepositoryPath lfs ls-files --json $Commit) -join "`n")
        if ($LASTEXITCODE -ne 0) { throw 'CANDIDATE_LFS_LIST_UNAVAILABLE' }
        foreach ($pointer in ($listing|ConvertFrom-Json).files) {
            if ($pointer.oid_type -cne 'sha256' -or $pointer.oid -cnotmatch '^[0-9a-f]{64}$' -or $pointer.version -cne 'https://git-lfs.github.com/spec/v1' -or -not $entries.ContainsKey([string]$pointer.name) -or $lfsEntries.ContainsKey([string]$pointer.name)) { throw 'CANDIDATE_LFS_POINTER_INVALID' }
            $lfsEntries[[string]$pointer.name]=$pointer
        }
    }
    foreach ($file in $Files) {
        if (-not $entries.ContainsKey([string]$file.path)) { throw 'CANDIDATE_SNAPSHOT_FILE_SET_MISMATCH' }
        $path=Join-Path $ToolkitPath $file.path
        if ($RestoredLfs -and $lfsEntries.ContainsKey([string]$file.path)) {
            $pointer=$lfsEntries[[string]$file.path]
            if ($file.sha256 -cne $pointer.oid -or [long]$file.length -ne [long]$pointer.size) { throw "CANDIDATE_LFS_CONTENT_MISMATCH:$($file.path)" }
            continue
        }
        $stream=[IO.File]::OpenRead($path)
        $hash=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA1)
        try {
            $hash.AppendData([Text.Encoding]::ASCII.GetBytes("blob $($stream.Length)"+[char]0))
            $buffer=[byte[]]::new(131072)
            while (($count=$stream.Read($buffer,0,$buffer.Length)) -gt 0) { $hash.AppendData($buffer,0,$count) }
            $oid=[Convert]::ToHexString($hash.GetHashAndReset()).ToLowerInvariant()
            if ($oid -cne $entries[[string]$file.path]) { throw "CANDIDATE_SNAPSHOT_BLOB_MISMATCH:$($file.path)" }
        } finally { $hash.Dispose();$stream.Dispose() }
    }
}

function Get-PbLocalToolkitCandidateIdentity {
    <# .SYNOPSIS Verifies actual isolated content without inventing a Toolkit commit or release qualification. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ToolkitPath,[Parameter(Mandatory)][string]$ExpectedProductVersion,
        [string]$Commit,[string]$SnapshotRepositoryPath,[switch]$RestoredLfs,[switch]$DeferEntrypoint)
    if ([bool]$Commit -ne [bool]$SnapshotRepositoryPath -or ($Commit -and $Commit -cnotmatch '^[0-9a-f]{40}$')) { throw 'CANDIDATE_SNAPSHOT_PARAMETERS_INVALID' }
    $root = Assert-PbReleasePlainPath -Path $ToolkitPath -Recurse
    if ((Test-Path -LiteralPath (Join-Path $root '.git')) -and (-not $Commit -or [IO.Path]::GetFullPath($SnapshotRepositoryPath) -cne $root)) { throw 'CANDIDATE_GIT_METADATA_UNEXPECTED' }
    $manifestPath = Join-Path $root 'manifest.json'
    $contractPath = Join-Path $root 'checks/toolkit-runtime-contract.json'
    $manifestText = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8
    $contractText = Get-Content -LiteralPath $contractPath -Raw -Encoding utf8
    $manifest = $manifestText | ConvertFrom-Json
    $contract = $contractText | ConvertFrom-Json
    if ($manifestText -match '"(?:manifestSha256|toolkitCommit)"\s*:' -or $contractText -match '"(?:runtimeContractSha256|toolkitCommit)"\s*:') { throw 'CANDIDATE_IDENTITY_SELF_REFERENCE' }
    foreach ($actual in @($manifest.productVersion,$manifest.toolkitVersion,$contract.toolkitVersion,$contract.cliDoctorContractVersion,
        (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw -Encoding utf8).Trim())) {
        if ([string]$actual -cne $ExpectedProductVersion) { throw 'CANDIDATE_VERSION_MISMATCH' }
    }
    if (-not $manifest.candidatePreparation -or -not $manifest.developmentOnly -or $manifest.sourceAdoption -cne 'pending' -or
        $manifest.qualification -cne 'candidate-preparation-source-adoption-and-independent-qualification-pending' -or
        -not $contract.candidatePreparation -or $contract.sourceAdoption -cne 'pending') { throw 'CANDIDATE_SCOPE_INVALID' }
    $files = @(Get-ChildItem -LiteralPath $root -Force | Where-Object Name -CNE '.git' | ForEach-Object {
        if ($_.PSIsContainer) { Get-ChildItem -LiteralPath $_.FullName -File -Force -Recurse } else { $_ }
    } | ForEach-Object {
        [pscustomobject]@{path=[IO.Path]::GetRelativePath($root,$_.FullName).Replace('\','/');length=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}
    })
    $paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $files) { if (-not $paths.Add($file.path)) { throw 'CANDIDATE_FILE_CASE_COLLISION' } }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($line in Get-Content -LiteralPath (Join-Path $root 'checks/SHA256SUMS.txt') -Encoding utf8) {
        if (-not $line) { continue }
        if ($line -cnotmatch '^([0-9a-f]{64})  (.+)$') { throw 'CANDIDATE_CHECKSUM_INVALID' }
        $hash=$Matches[1];$relative=$Matches[2]
        if ($relative -match '(^|/)\.\.?(/|$)|[\\:*?\x00-\x1f]' -or [IO.Path]::IsPathRooted($relative)) { throw 'CANDIDATE_CHECKSUM_PATH_INVALID' }
        if ($relative -ceq 'checks/SHA256SUMS.txt' -or -not $seen.Add($relative)) { throw 'CANDIDATE_CHECKSUM_SELF_REFERENCE_OR_DUPLICATE' }
        $entry = @($files | Where-Object path -CEQ $relative)
        if ($entry.Count -ne 1 -or $entry[0].sha256 -cne $hash) { throw "CANDIDATE_CHECKSUM_MISMATCH:$relative" }
    }
    foreach ($file in $files) {
        if ($file.path -ne 'checks/SHA256SUMS.txt' -and -not $seen.Contains($file.path)) { throw "CANDIDATE_CHECKSUM_COVERAGE_MISSING:$($file.path)" }
    }
    if ($contract.PSObject.Properties['runtimeInventory'] -or (Test-Path -LiteralPath (Join-Path $root 'checks/runtime-inventory.json'))) {
        # Some installed candidates bind the inventory through the complete Git tree
        # and SHA256SUMS rather than embedding its hash in the runtime contract.
        $inventoryRelative='checks/runtime-inventory.json'
        $inventoryHash=($files|Where-Object path -CEQ $inventoryRelative).sha256
        if ($contract.PSObject.Properties['runtimeInventory']) {
            $inventoryRelative=[string]$contract.runtimeInventory.path
            $inventoryHash=[string]$contract.runtimeInventory.sha256
        }
        if ($inventoryRelative -cne 'checks/runtime-inventory.json') { throw 'CANDIDATE_RUNTIME_INVENTORY_LOCATION_INVALID' }
        $inventory=Assert-PbReleaseInputInventory -Root $root -InventoryPath (Join-Path $root $inventoryRelative) -InventorySha256 $inventoryHash -ProductVersion $ExpectedProductVersion
        $runtimeFiles=@($files | Where-Object path -CLike 'runtime/*')
        if (@($inventory.files).Count -ne $runtimeFiles.Count -or @($inventory.files | Where-Object path -CNotLike 'runtime/*').Count) { throw 'CANDIDATE_RUNTIME_INVENTORY_NOT_CLOSED' }
        $runtimeSet=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($entry in $inventory.files) { $null=$runtimeSet.Add([string]$entry.path) }
        foreach ($file in $runtimeFiles) { if (-not $runtimeSet.Contains($file.path)) { throw 'CANDIDATE_RUNTIME_INVENTORY_NOT_CLOSED' } }
    }
    $snapshot=$null
    if ($Commit) {
        Assert-PbToolkitSnapshotFiles -ToolkitPath $root -RepositoryPath $SnapshotRepositoryPath -Commit $Commit -Files $files -RestoredLfs:$RestoredLfs
        $snapshot=Get-PbToolkitSnapshotIdentity -ToolkitPath $SnapshotRepositoryPath -Commit $Commit
        foreach ($pair in @(@('manifest.json','manifestSha256'),@('checks/toolkit-runtime-contract.json','runtimeContractSha256'),@('runtime/cli/win-x86/PbBridge.Cli.exe','cliSha256'))) {
            if ((Get-PbReleaseFileIdentity (Join-Path $root $pair[0])).sha256 -cne [string]$snapshot.identity.($pair[1])) { throw 'CANDIDATE_SNAPSHOT_IDENTITY_MISMATCH' }
        }
    }
    $binaries = @(Get-PbCandidateRuntimeBinaryFact -RuntimeRoot (Join-Path $root 'runtime') -ExpectedProductVersion $ExpectedProductVersion)
    $cli = Join-Path $root 'runtime/cli/win-x86/PbBridge.Cli.exe'
    if (-not $DeferEntrypoint) {
        $version = & $cli version
        if ($LASTEXITCODE -ne 0 -or [string](($version -join "`n" | ConvertFrom-Json).version) -cne $ExpectedProductVersion) { throw 'CANDIDATE_ENTRYPOINT_VERSION_MISMATCH' }
    }
    [pscustomobject]@{identity=[pscustomobject]@{productVersion=$ExpectedProductVersion;toolkitCommit=$(if ($snapshot) { $Commit } else { $null });
        cliSha256=(Get-PbReleaseFileIdentity $cli).sha256;manifestSha256=(Get-PbReleaseFileIdentity $manifestPath).sha256;
        runtimeContractSha256=(Get-PbReleaseFileIdentity $contractPath).sha256};files=$files;checksums=$seen.Count;binaries=$binaries;
        missingIdentityFields=$(if ($snapshot) { @() } else { @('toolkitCommit') });
        qualification=$(if ($snapshot) { 'local-committed-source-and-toolkit-candidate-validation/7.6.0' } else { 'local-content-only' });publishable=$false}
}

function Get-PbScoped753PublicationFact {
    # This historical exception is anchored to the immutable completion bytes, not arbitrary status=published JSON.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RecordPath,[Parameter(Mandatory)][string]$PublicationReceiptPath,
        [Parameter(Mandatory)][string]$ArtifactRoot,[Parameter(Mandatory)][object]$Record)
    $null = Assert-PbReleasePlainPath $RecordPath
    $null = Assert-PbReleasePlainPath $PublicationReceiptPath
    $receiptReference=Get-PbReleaseFileIdentity $PublicationReceiptPath
    if ($receiptReference.sha256 -cne '89ebd7e86b001c012d7dd8d60ede7780901a3e3970f033a8614313bd03226f7e') { throw 'SCOPED_PUBLICATION_COMPLETION_UNRECOGNIZED' }
    $receipt=Get-Content -LiteralPath $PublicationReceiptPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
    $referenceRoot=Split-Path -Parent ([IO.Path]::GetFullPath($PublicationReceiptPath))
    foreach ($pair in @(@('decisionDocument','7.5.3-owner-authorized-scoped-release.json'),@('previousPartialReceipt','7.5.3-publication-receipt.json'))) {
        $reference=$receipt.($pair[0])
        if ([string]$reference.path -cne ('docs/releases/'+$pair[1])) { throw 'SCOPED_PUBLICATION_CHAIN_PATH_INVALID' }
        $path=Join-Path $referenceRoot $pair[1]
        $null=Assert-PbReleasePlainPath $path
        if ((Get-PbReleaseFileIdentity $path).sha256 -cne [string]$reference.sha256) { throw 'SCOPED_PUBLICATION_CHAIN_DRIFTED' }
    }
    $decision=Get-Content -LiteralPath (Join-Path $referenceRoot '7.5.3-owner-authorized-scoped-release.json') -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
    $partial=Get-Content -LiteralPath (Join-Path $referenceRoot '7.5.3-publication-receipt.json') -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
    if ($receipt.schemaName -cne 'pbbridge-owner-scoped-publication-completion' -or $decision.schemaName -cne 'pbbridge-owner-authorized-scoped-release' -or
        $partial.schemaName -cne 'pbbridge-owner-scoped-publication-receipt' -or $receipt.productVersion -cne '7.5.3' -or $Record.productVersion -cne '7.5.3' -or
        $decision.productVersion -cne '7.5.3' -or $partial.productVersion -cne '7.5.3' -or -not $decision.oneReleaseOnly -or
        $receipt.publicationDecision -cne 'owner-authorized-scoped-release' -or $decision.publicationDecision -cne $receipt.publicationDecision -or
        $receipt.status -cne 'published' -or -not $receipt.allPublicationStepsCompleted -or
        $receipt.originalFullQualification.status -cne 'not-completed' -or $receipt.originalQualificationReclassifiedAsPass -or $receipt.formalManifestFinalizationClaimed) { throw 'SCOPED_PUBLICATION_SCOPE_INVALID' }
    foreach ($field in @('productVersion','cliSha256','manifestSha256','runtimeContractSha256','toolkitCommit')) {
        $expected=if($field -ceq 'toolkitCommit'){[string]$Record.candidate.toolkit.commit}else{[string]$Record.candidate.buildIdentity.$field}
        if ([string]$receipt.identity.$field -cne $expected -or [string]$decision.identity.$field -cne $expected -or [string]$partial.identity.$field -cne $expected) { throw "SCOPED_PUBLICATION_IDENTITY_MISMATCH:$field" }
    }
    $archives=@($receipt.distribution.archives | Where-Object name -CEQ 'PbBridge.Toolkit-7.5.3.zip')
    $approved=@($decision.assets | Where-Object name -CEQ 'PbBridge.Toolkit-7.5.3.zip')
    if ($archives.Count -ne 1 -or $approved.Count -ne 1 -or $archives[0].sha256 -cne $approved[0].sha256 -or $archives[0].length -ne $approved[0].length) { throw 'SCOPED_PUBLICATION_ARTIFACT_MISMATCH' }
    $artifactDirectory=Assert-PbReleasePlainPath $ArtifactRoot
    $archive=Join-Path $artifactDirectory $archives[0].name
    $null=Assert-PbReleasePlainPath $archive
    $artifact=Assert-PbReleaseFrozenReference $archive $archives[0]
    # A projection describes the actual published ZIP; the earlier pre-tag record/ZIP remain unchanged.
    $candidate=$Record.candidate | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
    $candidate.repository.commit=[string]$receipt.releaseSourceCommit
    $candidate.repository.tagStatus='verified'
    $candidate.repository.tagObject=[string]$receipt.tagObject
    $candidate.repository.peeledCommit=[string]$receipt.tagPeeledCommit
    $candidate.releaseArtifacts=@([pscustomobject]@{path=$archives[0].name;sha256=$artifact.sha256;length=$artifact.length})
    [pscustomobject]@{record=$Record;candidate=$candidate;recordReference=(Get-PbReleaseFileIdentity $RecordPath);receiptReference=$receiptReference;
        publicationEvidenceReference=$null;published=$true;publicationScope='owner-authorized-scoped-release/7.5.3';
        fullQualification='not-completed';formalManifestFinalization=$false;authorizationTransferable=$false;artifact=$artifact}
}

function Assert-PbInstalledCandidateSource {
    param([string]$ToolkitPath,[string]$Commit,[string]$TargetCommit,[string]$Remote)
    $url=(@(& git -C $ToolkitPath remote get-url --all $Remote 2>$null) -join "`n").Trim()
    if ($LASTEXITCODE -ne 0 -or $url -cnotmatch '\A(?:https://github\.com/dusdong/PbBridge\.Toolkit(?:\.git)?|git@github\.com:dusdong/PbBridge\.Toolkit(?:\.git)?|ssh://git@github\.com/dusdong/PbBridge\.Toolkit(?:\.git)?)\z') { throw 'candidate-recovery-source-not-official' }
    $head=(@(& git -C $ToolkitPath rev-parse HEAD) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $head -cne $Commit) { throw 'candidate-recovery-head-changed' }
    $dirty=@(& git -C $ToolkitPath status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0 -or $dirty.Count) { throw 'candidate-recovery-installation-dirty' }
    foreach ($pair in @(@($Commit,$TargetCommit),@($TargetCommit,"refs/remotes/$Remote/main"))) {
        & git -C $ToolkitPath merge-base --is-ancestor $pair[0] $pair[1] 2>$null
        if ($LASTEXITCODE -ne 0 -or $Commit -ceq $TargetCommit) { throw 'candidate-recovery-fast-forward-required' }
    }
    $targetVersion=(@(& git -C $ToolkitPath show "${TargetCommit}:VERSION") -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $targetVersion -cne '7.6.1') { throw 'candidate-recovery-target-version-unsupported' }
}

function Get-PbInstalledCandidateRecovery {
    <#
    .SYNOPSIS Prepares or read-only revalidates an installed 7.6.0 candidate copy.
    .DESCRIPTION Requires official main ancestry and a 7.6.1 fast-forward target. Never issues publication authority.
    .PARAMETER ExtractionRoot Explicit tree-external recovery directory; occupied incomplete directories are refused.
    .EXAMPLE Get-PbInstalledCandidateRecovery -ToolkitPath C:/install -Commit $old -TargetCommit $new -Remote github -ExtractionRoot C:/recovery/new -ProjectRoot C:/project
    .OUTPUTS Recovery status, five-part identity, full inventory and actual child-process output.
    .NOTES Copy preparation is permitted during updater WhatIf. Installation and business data remain read-only.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ToolkitPath,[Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$Commit,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$TargetCommit,[string]$Remote='github',
        [Parameter(Mandatory)][string]$ExtractionRoot,[Parameter(Mandatory)][string]$ProjectRoot,[switch]$RequireExisting)
    $executionLog=[Collections.Generic.List[object]]::new()
    try {
        $root=Assert-PbReleasePlainPath $ExtractionRoot -Recurse
        foreach ($protected in @($ToolkitPath,$ProjectRoot)) {
            $protected=[IO.Path]::GetFullPath($protected).TrimEnd('\','/')
            if ($root.Equals($protected,[StringComparison]::OrdinalIgnoreCase) -or $root.StartsWith($protected+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $protected.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'candidate-recovery-output-overlap' }
        }
        Assert-PbInstalledCandidateSource -ToolkitPath $ToolkitPath -Commit $Commit -TargetCommit $TargetCommit -Remote $Remote
        $installed=Get-PbLocalToolkitCandidateIdentity -ToolkitPath $ToolkitPath -ExpectedProductVersion '7.6.0' -Commit $Commit -SnapshotRepositoryPath $ToolkitPath -RestoredLfs -DeferEntrypoint
        if (@($installed.files|Where-Object path -CEQ 'checks/runtime-inventory.json').Count -ne 1) { throw 'candidate-recovery-runtime-inventory-required' }
        $copy=Join-Path $root 'toolkit';$recordPath=Join-Path $root 'recovery-record.json'
        $reuse=Test-Path -LiteralPath $root
        if ($reuse) {
            if (-not (Test-Path -LiteralPath $recordPath -PathType Leaf)) { throw 'candidate-recovery-interrupted-directory' }
            $record=Get-Content -LiteralPath $recordPath -Raw -Encoding utf8|ConvertFrom-Json -Depth 50
            if ($record.schemaName -cne 'pbbridge-installed-candidate-recovery' -or $record.recoveryKind -cne 'installed-candidate-copy' -or $record.status -cne 'verified' -or $record.extractedToolkit -cne $copy -or $record.publishable -ne $false -or $record.authorizationTransferable -ne $false) { throw 'candidate-recovery-record-invalid' }
            foreach ($field in @('productVersion','cliSha256','toolkitCommit','runtimeContractSha256','manifestSha256')) {
                if ([string]$record.identity.$field -cne [string]$installed.identity.$field) { throw "candidate-recovery-record-identity-mismatch:$field" }
            }
            if (@(Get-ChildItem -LiteralPath $root -Force).Count -ne 2) { throw 'candidate-recovery-extra-material' }
        } else {
            if ($RequireExisting) { throw 'candidate-recovery-copy-required' }
            $null=[IO.Directory]::CreateDirectory($copy)
            foreach ($file in $installed.files) {
                $destination=Join-Path $copy $file.path
                $null=[IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
                [IO.File]::Copy((Join-Path $ToolkitPath $file.path),$destination,$false)
            }
        }
        $verified=Get-PbLocalToolkitCandidateIdentity -ToolkitPath $copy -ExpectedProductVersion '7.6.0' -Commit $Commit -SnapshotRepositoryPath $ToolkitPath -RestoredLfs -DeferEntrypoint
        if ($reuse) {
            if ($record.source -cne 'https://github.com/dusdong/PbBridge.Toolkit.git' -or $record.qualification -cne 'candidate-recovery-only' -or $record.recoveryScope -cne 'toolkit-only' -or @($record.files).Count -ne $verified.files.Count -or @($record.executions).Count -ne 2) { throw 'candidate-recovery-record-incomplete' }
            $recordFiles=@{}
            foreach ($file in $record.files) {
                if ($recordFiles.ContainsKey([string]$file.path)) { throw 'candidate-recovery-record-inventory-invalid' }
                $recordFiles[[string]$file.path]=$file
            }
            foreach ($file in $verified.files) {
                if (-not $recordFiles.ContainsKey([string]$file.path) -or $recordFiles[[string]$file.path].sha256 -cne $file.sha256 -or [long]$recordFiles[[string]$file.path].length -ne $file.length) { throw 'candidate-recovery-record-inventory-invalid' }
            }
        }
        foreach ($field in @('productVersion','cliSha256','toolkitCommit','runtimeContractSha256','manifestSha256')) {
            if ([string]$verified.identity.$field -cne [string]$installed.identity.$field) { throw 'candidate-recovery-copy-identity-mismatch' }
        }
        $entry=Join-Path $copy 'runtime/cli/win-x86/PbBridge.Cli.exe'
        $executions=@(foreach ($command in @('version','doctor')) {
            $info=[Diagnostics.ProcessStartInfo]::new(@(Get-Command pwsh -CommandType Application)[0].Source)
            $info.UseShellExecute=$false;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;$info.WorkingDirectory=$copy
            $commandText="& '"+$entry.Replace("'","''")+"' '"+$command+"'; exit `$LASTEXITCODE"
            $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($commandText))
            foreach ($arg in @('-NoProfile','-NonInteractive','-EncodedCommand',$encoded)) { $info.ArgumentList.Add($arg) }
            $process=[Diagnostics.Process]::Start($info)
            $out=$process.StandardOutput.ReadToEndAsync();$err=$process.StandardError.ReadToEndAsync()
            $process.WaitForExit();$stdout=$out.GetAwaiter().GetResult();$stderr=$err.GetAwaiter().GetResult();$code=$process.ExitCode;$pidValue=$process.Id;$process.Dispose()
            $executionLog.Add([pscustomobject]@{command=$command;entrypoint=$entry;pid=$pidValue;exitCode=$code;stdout=$stdout;stderr=$stderr})
            if ($code -ne 0) { throw "candidate-recovery-entrypoint-failed:$command exit=$code $stderr" }
            if ($command -ceq 'version' -and [string](($stdout|ConvertFrom-Json).version) -cne '7.6.0') { throw 'candidate-recovery-entrypoint-version-mismatch' }
            [pscustomobject]@{command=$command;entrypoint=$entry;pid=$pidValue;exitCode=$code;stdout=$stdout;stderr=$stderr}
        })
        # Detect any entrypoint side effect or concurrent installation change before issuing a record.
        $null=Get-PbLocalToolkitCandidateIdentity -ToolkitPath $copy -ExpectedProductVersion '7.6.0' -Commit $Commit -SnapshotRepositoryPath $ToolkitPath -RestoredLfs -DeferEntrypoint
        Assert-PbInstalledCandidateSource -ToolkitPath $ToolkitPath -Commit $Commit -TargetCommit $TargetCommit -Remote $Remote
        $null=Get-PbLocalToolkitCandidateIdentity -ToolkitPath $ToolkitPath -ExpectedProductVersion '7.6.0' -Commit $Commit -SnapshotRepositoryPath $ToolkitPath -RestoredLfs -DeferEntrypoint
        $result=[ordered]@{schemaName='pbbridge-installed-candidate-recovery';status='verified';reasonCode=$null;recoveryKind='installed-candidate-copy';recoveryScope='toolkit-only';qualification='candidate-recovery-only';publishable=$false;authorizationTransferable=$false;identity=$installed.identity;source='https://github.com/dusdong/PbBridge.Toolkit.git';extractedToolkit=$copy;entrypoint=$entry;files=$verified.files;executions=$executions;requiresCurrentFacts=$true;businessRestored=$false;reused=$reuse}
        if (-not $reuse) {
            $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($result|ConvertTo-Json -Depth 50))
            $stream=[IO.File]::Open($recordPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
            try { $stream.Write($bytes);$stream.Flush($true) } finally { $stream.Dispose() }
        }
        [pscustomobject]$result
    } catch {
        [pscustomobject]@{status='unavailable';reasonCode=$_.Exception.Message;recoveryKind='installed-candidate-copy';recoveryScope='toolkit-only';qualification='candidate-recovery-only';publishable=$false;authorizationTransferable=$false;executions=$executionLog.ToArray()}
    }
}

Export-ModuleMember -Function Get-PbInstalledCandidateRecovery,Assert-PbToolkitSnapshotFiles,Get-PbCandidatePreservedInput,Assert-PbReleasePlainPath,Assert-PbReleaseInputInventory,Get-PbCandidateRuntimeBinaryFact,Get-PbLocalToolkitCandidateIdentity,Get-PbReleaseFileIdentity,Write-PbReleaseFrozenFile,Assert-PbReleaseFrozenReference,New-PbReleasePublicationReceipt,Get-PbPublishedReleaseFact,Get-PbReleaseRecoveryPreview,Get-PbToolkitSnapshotIdentity
