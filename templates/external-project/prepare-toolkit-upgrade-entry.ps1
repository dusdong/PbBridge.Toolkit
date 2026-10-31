#requires -PSEdition Core
#requires -Version 7.4
<#
.SYNOPSIS Prepare and optionally run a commit-bound updater without importing the old wrapper.
.DESCRIPTION The repository must already have fetched official main. Does not fetch, migrate remotes or alter the installation.
.PARAMETER EntryRoot New independent directory, or an existing exact three-file entry for read-only verification.
.PARAMETER Run Run only after comparing all three files with Git blobs again, in a new PowerShell process.
.EXAMPLE ./scripts/prepare-toolkit-upgrade-entry.ps1 -ToolkitRepository C:/toolkit -TargetCommit $sha -EntryRoot C:/tasks/entry
.OUTPUTS Prepared file identities, or the exit code of the new updater process.
.NOTES UpdaterArguments are passed as individual process arguments. Use explicit project and Toolkit roots.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ToolkitRepository,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$TargetCommit,
    [Parameter(Mandatory)][string]$EntryRoot,[string]$Remote='github',
    [switch]$Run,[string[]]$UpdaterArguments)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repository=[IO.Path]::GetFullPath($ToolkitRepository)
$output=[IO.Path]::GetFullPath($EntryRoot).TrimEnd('\','/')
if (-not [IO.Path]::IsPathFullyQualified($EntryRoot) -or $output -eq $repository -or $output.StartsWith($repository.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'upgrade-entry-output-invalid' }
$current=$output
while ($current) {
    if ((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'upgrade-entry-reparse-path' }
    $parent=Split-Path -Parent $current
    if ($parent -eq $current) { break };$current=$parent
}
$url=(@(& git -C $repository remote get-url --all $Remote) -join "`n").Trim()
if ($LASTEXITCODE -ne 0 -or $url -cnotmatch '\A(?:https://github\.com/dusdong/PbBridge\.Toolkit(?:\.git)?|git@github\.com:dusdong/PbBridge\.Toolkit(?:\.git)?|ssh://git@github\.com/dusdong/PbBridge\.Toolkit(?:\.git)?)\z') { throw 'upgrade-entry-source-not-official' }
& git -C $repository merge-base --is-ancestor $TargetCommit "refs/remotes/$Remote/main"
if ($LASTEXITCODE -ne 0) { throw 'upgrade-entry-target-not-official-main-history' }
$names=@('pbbridge-toolkit-update.ps1','PbBridge.Wrapper.psm1','PbBridge.ReleaseIdentity.psm1')
$inputs=@(foreach ($name in $names) {
    $info=[Diagnostics.ProcessStartInfo]::new('git')
    $info.UseShellExecute=$false;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    foreach ($arg in @('-C',$repository,'cat-file','blob',"${TargetCommit}:templates/external-project/$name")) { $info.ArgumentList.Add($arg) }
    $process=[Diagnostics.Process]::Start($info);$errors=$process.StandardError.ReadToEndAsync();$memory=[IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory);$process.WaitForExit();$null=$errors.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw "upgrade-entry-blob-missing:$name" }
        $bytes=$memory.ToArray()
        if ([Text.Encoding]::UTF8.GetString($bytes).StartsWith('version https://git-lfs.github.com/spec/')) { throw "upgrade-entry-pointer-forbidden:$name" }
        [pscustomobject]@{name=$name;bytes=$bytes;sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()}
    } finally { $memory.Dispose();$process.Dispose() }
})
if (-not (Test-Path -LiteralPath $output)) {
    if ($Run) { throw 'upgrade-entry-prepare-first' }
    $null=[IO.Directory]::CreateDirectory($output)
    foreach ($inputFile in $inputs) { [IO.File]::WriteAllBytes((Join-Path $output $inputFile.name),$inputFile.bytes) }
}
if (@(Get-ChildItem -LiteralPath $output -Force).Count -ne $names.Count) { throw 'upgrade-entry-file-set-mismatch' }
foreach ($inputFile in $inputs) {
    $path=Join-Path $output $inputFile.name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -or (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -cne $inputFile.sha256) { throw "upgrade-entry-content-mismatch:$($inputFile.name)" }
}
if ($Run) {
    if (-not $UpdaterArguments) { throw 'upgrade-entry-explicit-arguments-required' }
    $info=[Diagnostics.ProcessStartInfo]::new(@(Get-Command pwsh -CommandType Application)[0].Source)
    $info.UseShellExecute=$false;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    foreach ($arg in @('-NoProfile','-NonInteractive','-File',(Join-Path $output $names[0]))+$UpdaterArguments) { $info.ArgumentList.Add($arg) }
    $process=[Diagnostics.Process]::Start($info)
    $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    $process.WaitForExit();$code=$process.ExitCode
    Write-Output $stdout.GetAwaiter().GetResult()
    [Console]::Error.Write($stderr.GetAwaiter().GetResult())
    $process.Dispose();exit $code
}
[pscustomobject]@{targetCommit=$TargetCommit;source=$url;entryRoot=$output;files=@($inputs|Select-Object name,sha256);executed=$false}
