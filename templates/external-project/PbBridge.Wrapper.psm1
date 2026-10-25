#requires -PSEdition Core
#requires -Version 7.4

Set-StrictMode -Version Latest

function Show-PbBridgeWrapperHelp {
    <#
    .SYNOPSIS 显示受管 wrapper 帮助。
    .DESCRIPTION 输出 wrapper 定位、帮助入口和等价 CLI，不执行 workflow。
    .PARAMETER WrapperName wrapper 文件名。
    .PARAMETER CliCommand 对应 CLI 命令。
    .EXAMPLE Show-PbBridgeWrapperHelp -WrapperName 'pbbridge.ps1' -CliCommand 'pbbridge doctor'
    .OUTPUTS System.String
    .NOTES 共享 wrapper 基础设施。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WrapperName,

        [Parameter()]
        [string]$CliCommand = ''
    )

    $cliLine = if ([string]::IsNullOrWhiteSpace($CliCommand)) {
        '无对应 CLI help；请使用 -Help 查看本 wrapper 参数。'
    }
    else {
        "$CliCommand --help"
    }
    Write-Output @"
$WrapperName

说明：
  这是外部项目 PowerShell wrapper，只负责参数适配、ShouldProcess 和原生进程边界。

帮助入口：
  -Help     显示本 wrapper 帮助，不执行 workflow。
  -CliHelp  转发到对应 pbbridge CLI help。

workspace 映射：
  如本 wrapper 暴露 -WorkspaceName <id>，它只转发为 CLI --workspace <id>；wrapper 不推断多 workspace 默认值。

等价 CLI：
  $cliLine
"@
}

function Resolve-TemplateProjectRoot {
    <#
    .SYNOPSIS 解析外部项目根目录。
    .DESCRIPTION 优先使用显式根目录，其次使用脚本目录的父目录，最后使用当前目录。
    .PARAMETER ExplicitRoot 显式项目根目录。
    .PARAMETER ScriptRoot wrapper 脚本目录。
    .EXAMPLE Resolve-TemplateProjectRoot -ExplicitRoot '.'
    .OUTPUTS System.String
    .NOTES 返回规范化绝对路径。
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [Alias('ProjectRoot')]
        [string]$ExplicitRoot = '',

        [Parameter()]
        [string]$ScriptRoot = $PSScriptRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitRoot)) {
        return [System.IO.Path]::GetFullPath($ExplicitRoot)
    }
    if (-not [string]::IsNullOrWhiteSpace($ScriptRoot)) {
        return [System.IO.Path]::GetFullPath((Split-Path -Parent $ScriptRoot))
    }
    return [System.IO.Path]::GetFullPath((Get-Location).Path)
}

function Resolve-PbBridgeCliPath {
    <#
    .SYNOPSIS 解析受管 PbBridge CLI 路径。
    .DESCRIPTION 从项目内 Toolkit runtime 解析 win-x86 CLI，并对缺失 runtime 抛结构化错误。
    .PARAMETER ProjectRoot 外部项目根目录。
    .EXAMPLE Resolve-PbBridgeCliPath -ProjectRoot '.'
    .OUTPUTS System.String
    .NOTES 不搜索 PATH，避免运行错误版本。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectRoot
    )

    $cliPath = Join-Path ([System.IO.Path]::GetFullPath($ProjectRoot)) '.pbbridge\PbBridge.Toolkit\runtime\cli\win-x86\PbBridge.Cli.exe'
    if (-not (Test-Path -LiteralPath $cliPath -PathType Leaf)) {
        $exception = [System.IO.FileNotFoundException]::new('未找到 PbBridge.Cli.exe；请先安装或升级 Toolkit runtime。', $cliPath)
        $record = [System.Management.Automation.ErrorRecord]::new(
            $exception,
            'PbBridgeCliNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $cliPath)
        $PSCmdlet.ThrowTerminatingError($record)
    }
    return $cliPath
}

function Assert-PbBridgeWorkspaceId {
    <#
    .SYNOPSIS 校验可选的 V7 workspace selector。
    .DESCRIPTION 空值表示交由 CLI 自动选择唯一 workspace；非空值只允许小写字母、数字、下划线和连字符。
    .PARAMETER WorkspaceId V7 workspace id；不得传入 PBW 或目录路径。
    .EXAMPLE Assert-PbBridgeWorkspaceId -WorkspaceId 'canyin'
    .OUTPUTS None
    .NOTES 该函数只校验命令边界，不读取配置、不推导 workspace 路径。
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowEmptyString()]
        [string]$WorkspaceId = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($WorkspaceId) -and $WorkspaceId -notmatch '^[a-z0-9_-]+$') {
        throw "WorkspaceId 必须是 [a-z0-9_-]+，不得传入 PBW 或目录路径：$WorkspaceId"
    }
}

function Invoke-PbBridgeCliHelp {
    <#
    .SYNOPSIS 转发 CLI help。
    .DESCRIPTION 解析受管 runtime 后流式执行指定 CLI help 参数并保留退出码。
    .PARAMETER ProjectRoot 外部项目根目录。
    .PARAMETER Arguments CLI 参数。
    .EXAMPLE Invoke-PbBridgeCliHelp -ProjectRoot '.' -Arguments @('doctor','--help')
    .OUTPUTS None
    .NOTES 该函数按 CLI 退出码结束 wrapper 进程。
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProjectRoot = '',

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [string[]]$Arguments
    )

    $root = Resolve-TemplateProjectRoot -ExplicitRoot $ProjectRoot
    $cliPath = Resolve-PbBridgeCliPath -ProjectRoot $root
    $result = Invoke-PbBridgeNativeCommand -FilePath $cliPath -Arguments $Arguments -WorkingDirectory $root -Capture
    if (-not [string]::IsNullOrEmpty($result.stdout)) { [Console]::Out.Write($result.stdout) }
    if (-not [string]::IsNullOrEmpty($result.stderr)) { [Console]::Error.Write($result.stderr) }
    Complete-PbBridgeNativeCommand -Result $result
}

function Assert-PbBridgeRequiredParameter {
    <#
    .SYNOPSIS 校验 wrapper 必填参数。
    .DESCRIPTION 对 null、空字符串和空数组提供统一错误。
    .PARAMETER Name 参数名。
    .PARAMETER Value 参数值。
    .EXAMPLE Assert-PbBridgeRequiredParameter -Name 'Object' -Value $Object
    .OUTPUTS None
    .NOTES 只做边界校验，不推导业务策略。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        $Value
    )

    $missing = $null -eq $Value
    if (-not $missing -and $Value -is [string]) {
        $missing = [string]::IsNullOrWhiteSpace($Value)
    }
    elseif (-not $missing -and $Value -is [array]) {
        $missing = $Value.Count -eq 0
    }
    if ($missing) {
        throw "缺少必填参数 -$Name。请传入该参数，或运行 -Help 查看 wrapper 用法。"
    }
}

function ConvertTo-PbBridgeProcessArgument {
    <#
    .SYNOPSIS 转义 Windows 原生进程参数。
    .DESCRIPTION 为缺少 ProcessStartInfo.ArgumentList 的 Windows PowerShell 5.1 提供兼容转义。
    .PARAMETER Value 原始参数值。
    .EXAMPLE ConvertTo-PbBridgeProcessArgument -Value 'a b'
    .OUTPUTS System.String
    .NOTES pwsh 7 优先使用 ArgumentList，不经过此兼容路径。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    if ($Value -notmatch '[\s"]') {
        return $Value
    }
    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.Append('"')
    $backslashCount = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') {
            $backslashCount++
            continue
        }
        if ($character -eq '"') {
            [void]$builder.Append(('\' * ($backslashCount * 2 + 1)))
            [void]$builder.Append('"')
            $backslashCount = 0
            continue
        }
        if ($backslashCount -gt 0) {
            [void]$builder.Append(('\' * $backslashCount))
            $backslashCount = 0
        }
        [void]$builder.Append($character)
    }
    if ($backslashCount -gt 0) {
        [void]$builder.Append(('\' * ($backslashCount * 2)))
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-PbBridgeNativeCommand {
    <#
    .SYNOPSIS 调用原生命令。
    .DESCRIPTION 默认继承 stdout/stderr 句柄进行实时流式传播；Capture 捕获双流，CaptureStdout 仅捕获 stdout 并实时继承 stderr。
    .PARAMETER FilePath 原生可执行文件路径。
    .PARAMETER Arguments 原生参数数组。
    .PARAMETER WorkingDirectory 工作目录。
    .PARAMETER Capture 捕获 stdout/stderr，而不是直接流式传播。
    .PARAMETER CaptureStdout 仅捕获 stdout；stderr 继续实时写入继承句柄。
    .EXAMPLE Invoke-PbBridgeNativeCommand -FilePath 'pwsh' -Arguments @('-NoProfile','-Command','exit 0')
    .OUTPUTS System.Management.Automation.PSCustomObject
    .NOTES 返回退出码，不解析业务 JSON。
    #>
    [CmdletBinding(DefaultParameterSetName = 'Inherit')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [Alias('ArgumentList')]
        [ValidateNotNull()]
        [string[]]$Arguments,

        [Parameter()]
        [string]$WorkingDirectory = '',

        [Parameter(ParameterSetName = 'CaptureAll')]
        [switch]$Capture,

        [Parameter(ParameterSetName = 'CaptureStdout')]
        [switch]$CaptureStdout
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $Capture.IsPresent -or $CaptureStdout.IsPresent
    $startInfo.RedirectStandardError = $Capture.IsPresent
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        $startInfo.WorkingDirectory = [System.IO.Path]::GetFullPath($WorkingDirectory)
    }
    $argumentListProperty = $startInfo.GetType().GetProperty('ArgumentList')
    if ($null -ne $argumentListProperty) {
        foreach ($argument in $Arguments) {
            [void]$startInfo.ArgumentList.Add($argument)
        }
    }
    else {
        $startInfo.Arguments = ($Arguments | ForEach-Object { ConvertTo-PbBridgeProcessArgument -Value $_ }) -join ' '
    }

    try {
        $process = [System.Diagnostics.Process]::Start($startInfo)
    }
    catch {
        $record = [System.Management.Automation.ErrorRecord]::new(
            $_.Exception,
            'PbBridgeNativeProcessStartFailed',
            [System.Management.Automation.ErrorCategory]::OpenError,
            $FilePath)
        $PSCmdlet.ThrowTerminatingError($record)
    }
    if ($null -eq $process) {
        throw "无法启动原生进程：$FilePath"
    }

    try {
        $stdout = ''
        $stderr = ''
        if ($Capture.IsPresent) {
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            $process.WaitForExit()
            [System.Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask))
            $stdout = $stdoutTask.GetAwaiter().GetResult()
            $stderr = $stderrTask.GetAwaiter().GetResult()
        }
        elseif ($CaptureStdout.IsPresent) {
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $process.WaitForExit()
            $stdout = $stdoutTask.GetAwaiter().GetResult()
        }
        else {
            $process.WaitForExit()
        }
        $stdoutCaptured = $Capture.IsPresent -or $CaptureStdout.IsPresent
        return [pscustomobject]@{
            exitCode = [int]$process.ExitCode
            stdout = $stdout
            stderr = $stderr
            captured = $stdoutCaptured
            stdoutCaptured = $stdoutCaptured
            stderrCaptured = $Capture.IsPresent
            filePath = $FilePath
            arguments = @($Arguments)
        }
    }
    finally {
        $process.Dispose()
    }
}

function Complete-PbBridgeNativeCommand {
    <#
    .SYNOPSIS 完成原生命令边界。
    .DESCRIPTION 将捕获的 stdout 写入 PowerShell success stream，将捕获的 stderr 写入进程 stderr，并返回或作为 wrapper 进程退出码结束。
    .PARAMETER Result Invoke-PbBridgeNativeCommand 返回的结构化结果。
    .PARAMETER ReturnExitCode 返回退出码而不结束当前进程。
    .EXAMPLE Complete-PbBridgeNativeCommand -Result $result -ReturnExitCode
    .OUTPUTS System.Int32 when ReturnExitCode is present; otherwise none.
    .NOTES 不修改 CLI 退出码。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Result,

        [Parameter()]
        [switch]$ReturnExitCode
    )

    $stdoutCaptured = if ($Result.PSObject.Properties.Name -contains 'stdoutCaptured') {
        [bool]$Result.stdoutCaptured
    }
    else {
        [bool]$Result.captured
    }
    $stderrCaptured = if ($Result.PSObject.Properties.Name -contains 'stderrCaptured') {
        [bool]$Result.stderrCaptured
    }
    else {
        [bool]$Result.captured
    }

    if ($stdoutCaptured -and -not [string]::IsNullOrEmpty([string]$Result.stdout)) {
        $stdout = ([string]$Result.stdout).TrimEnd([char[]]"`r`n")
        if (-not [string]::IsNullOrEmpty($stdout)) {
            Write-Output -NoEnumerate $stdout
        }
    }
    if ($stderrCaptured -and -not [string]::IsNullOrEmpty([string]$Result.stderr)) {
        [Console]::Error.Write([string]$Result.stderr)
    }
    if ($ReturnExitCode.IsPresent) {
        return [int]$Result.exitCode
    }
    exit ([int]$Result.exitCode)
}

Export-ModuleMember -Function `
    Show-PbBridgeWrapperHelp, `
    Resolve-TemplateProjectRoot, `
    Resolve-PbBridgeCliPath, `
    Assert-PbBridgeWorkspaceId, `
    Invoke-PbBridgeCliHelp, `
    Assert-PbBridgeRequiredParameter, `
    ConvertTo-PbBridgeProcessArgument, `
    Invoke-PbBridgeNativeCommand, `
    Complete-PbBridgeNativeCommand
