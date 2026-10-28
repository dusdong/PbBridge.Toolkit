# PbBridge-TemplateVersion: 7.6.0
param()

$minimumVersion = [version]'7.4.0'
$observedEdition = [string]$PSVersionTable.PSEdition
$observedVersion = [version]$PSVersionTable.PSVersion
$ready = $observedEdition -eq 'Core' -and $observedVersion -ge $minimumVersion
$pwshPath = $null
try {
    $command = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        $pwshPath = [string]$command.Source
    }
}
catch {
    $pwshPath = $null
}

$result = [ordered]@{
    schemaName = 'pbbridge-runtime-admission'
    schemaVersion = 1
    status = if ($ready) { 'ready' } else { 'blocked' }
    blocked = -not $ready
    reasonCode = if ($ready) { $null } else { 'PWSH_7_REQUIRED' }
    observed = [ordered]@{
        edition = $observedEdition
        version = $observedVersion.ToString()
        executable = [string](Get-Process -Id $PID).Path
    }
    required = [ordered]@{
        edition = 'Core'
        minimumVersion = $minimumVersion.ToString()
        executable = 'pwsh'
    }
    discoveredPwshPath = $pwshPath
    nextAction = if ($ready) {
        '当前宿主满足 PbBridge.Toolkit 业务运行时要求。'
    }
    elseif ([string]::IsNullOrWhiteSpace($pwshPath)) {
        '安装 PowerShell 7.4 或更高版本，然后使用 pwsh 重新运行 PbBridge.Toolkit 命令。'
    }
    else {
        "使用 '$pwshPath' 重新运行 PbBridge.Toolkit 命令。"
    }
}

[Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 6 -Compress))
if (-not $ready) {
    exit 10
}
