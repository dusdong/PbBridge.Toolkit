#requires -PSEdition Core
#requires -Version 7.4
Set-StrictMode -Version Latest

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
    param([Parameter(Mandatory)][string]$RecordPath,[string]$PublicationReceiptPath,[string]$ExpectedProductVersion)
    $record=Get-Content -LiteralPath $RecordPath -Raw -Encoding utf8|ConvertFrom-Json -Depth 100
    Assert-PbPublishedRecordIdentity -Record $record
    $version=[string]$record.productVersion;$candidate=$record.candidate
    if ($ExpectedProductVersion -and $version -cne $ExpectedProductVersion) { throw 'RELEASE_PUBLISHED_IDENTITY_INVALID' }
    $receiptReference=$null;$proofReference=$null
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
    $identity=[ordered]@{productVersion=$version;cliSha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($cliBytes)).ToLowerInvariant();
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
        [Parameter(Mandatory)][string]$ExtractionRoot,[string]$PublicationReceiptPath)
    $identity=$null;$archive=$null
    try {
        $record=Get-Content -LiteralPath $RecordPath -Raw -Encoding utf8|ConvertFrom-Json
        if([string]$record.schemaName -cne 'pbbridge-replacement-release-record' -or [int]$record.recordVersion -ne 3){throw 'recovery-record-unsupported'}
        $published=Get-PbPublishedReleaseFact -RecordPath $RecordPath -PublicationReceiptPath $PublicationReceiptPath
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
        $cli=Join-Path $toolkit 'runtime/cli/win-x86/PbBridge.Cli.exe'
        $versionOutput=& $cli version
        if($LASTEXITCODE -ne 0 -or [string](($versionOutput -join "`n"|ConvertFrom-Json).version) -cne $identity.productVersion){throw 'recovery-entrypoint-failed'}
        $doctorOutput=& $cli doctor
        if($LASTEXITCODE -ne 0){throw 'recovery-doctor-failed'}
        [pscustomobject]@{status='verified';reasonCode=$null;identity=$identity;artifact=$archiveVerification.artifact;artifactLengthSource=$archiveVerification.lengthSource;extractedToolkit=$toolkit;
            entrypoint=$cli;doctorOutput=($doctorOutput -join "`n");recoveryScope='toolkit-only';requiresCurrentFacts=$true;businessRestored=$false}
    } catch {
        [pscustomobject]@{status='unavailable';reasonCode=$_.Exception.Message;identity=$identity;artifactPath=$archive;
            recoveryScope='toolkit-only';requiresCurrentFacts=$true;businessRestored=$false}
    }
}

Export-ModuleMember -Function Get-PbReleaseFileIdentity,Write-PbReleaseFrozenFile,Assert-PbReleaseFrozenReference,New-PbReleasePublicationReceipt,Get-PbPublishedReleaseFact,Get-PbReleaseRecoveryPreview,Get-PbToolkitSnapshotIdentity
