#requires -Version 5.1

[CmdletBinding()]
param(
    [string]$InstallRoot = $(Join-Path $env:LOCALAPPDATA 'Troon\MultiMouseControl'),

    [string]$ConfigPath = $(Join-Path $env:USERPROFILE '.codex\config.toml'),

    [ValidateRange(1, 65535)]
    [int]$Port = 41760,

    [string]$ReportPath = $(Join-Path $env:LOCALAPPDATA 'Troon\MultiMouseControl\state\verification.json'),

    [switch]$Strict
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'MultiMouseControl.Core.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

$checks = [System.Collections.Generic.List[object]]::new()
$addCheck = {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Severity,
        [string]$Detail
    )

    $checks.Add([pscustomobject][ordered]@{
        name = $Name
        passed = $Passed
        severity = $Severity
        detail = $Detail
    })
}

& $addCheck 'Windows operating system' ($env:OS -eq 'Windows_NT') 'critical' "OS=$($env:OS)"

$installRootFull = [IO.Path]::GetFullPath($InstallRoot)
& $addCheck 'Package install root' (Test-Path -LiteralPath $installRootFull) 'critical' $installRootFull

$corePath = Join-Path $installRootFull 'scripts\MultiMouseControl.Core.psm1'
& $addCheck 'Core module installed' (Test-Path -LiteralPath $corePath) 'critical' $corePath

$taskExists = $false
try {
    $taskExists = $null -ne (Get-ScheduledTask -TaskName 'MultiMouseControl-ForceStop' -ErrorAction Stop)
} catch {
    $taskExists = $false
}
& $addCheck 'Elevated force-stop task' $taskExists 'critical' 'Scheduled task: MultiMouseControl-ForceStop'

$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'FORCE STOP - MouseMux.lnk'
& $addCheck 'Force-stop desktop shortcut' (Test-Path -LiteralPath $shortcutPath) 'warning' $shortcutPath

$installerPath = Join-Path $installRootFull 'downloads\mousemux-v3-setup-3.0.19.exe'
$installerExists = Test-Path -LiteralPath $installerPath
& $addCheck 'Pinned MouseMux installer present' $installerExists 'warning' $installerPath
if ($installerExists) {
    $signature = Get-AuthenticodeSignature -LiteralPath $installerPath
    & $addCheck 'MouseMux installer signature valid' ($signature.Status -eq [System.Management.Automation.SignatureStatus]::Valid) 'critical' ([string]$signature.Status)
}

$processes = @()
try {
    $processes = @(Get-CimInstance Win32_Process -ErrorAction Stop)
} catch {
    $processes = @()
}

$verifiedProcesses = @(
    foreach ($process in $processes) {
        $identityParameters = @{
            Name = [string]$process.Name
            ExecutablePath = [string]$process.ExecutablePath
            CommandLine = [string]$process.CommandLine
        }
        if (Test-MouseMuxProcessIdentity @identityParameters) {
            $process
        }
    }
)
& $addCheck 'Verified MouseMux process running' ($verifiedProcesses.Count -gt 0) 'warning' ("Count={0}" -f $verifiedProcesses.Count)

$listenerPids = @()
try {
    $listenerPids = @(
        Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop |
            Select-Object -ExpandProperty OwningProcess -Unique
    )
} catch {
    $listenerPids = @()
}
& $addCheck 'Input Mapper MCP port listening' ($listenerPids.Count -gt 0) 'warning' ("Port={0}; PIDs={1}" -f $Port, ([string]::Join(',', $listenerPids)))

$allListenersVerified = $true
foreach ($listenerPid in $listenerPids) {
    $listenerProcess = $processes | Where-Object { [int]$_.ProcessId -eq [int]$listenerPid } | Select-Object -First 1
    if ($null -eq $listenerProcess) {
        $allListenersVerified = $false
        continue
    }

    $listenerIdentityParameters = @{
        Name = [string]$listenerProcess.Name
        ExecutablePath = [string]$listenerProcess.ExecutablePath
        CommandLine = [string]$listenerProcess.CommandLine
    }
    if (-not (Test-MouseMuxProcessIdentity @listenerIdentityParameters)) {
        $allListenersVerified = $false
    }
}
if ($listenerPids.Count -eq 0) {
    $allListenersVerified = $false
}
& $addCheck 'MCP port owner identity verified' $allListenersVerified 'critical' 'Every listener on port 41760 must be a verified MouseMux process.'

$configExists = Test-Path -LiteralPath $ConfigPath
& $addCheck 'Codex configuration exists' $configExists 'warning' $ConfigPath
$configHasMouseMux = $false
$configUsesPrompt = $false
if ($configExists) {
    $configContent = [IO.File]::ReadAllText([IO.Path]::GetFullPath($ConfigPath))
    $configHasMouseMux = $configContent -match '(?m)^\s*\[mcp_servers\.mousemux\]\s*$'
    $configUsesPrompt = $configContent -match '(?m)^\s*default_tools_approval_mode\s*=\s*"prompt"\s*$'
}
& $addCheck 'MouseMux MCP configured' $configHasMouseMux 'critical' 'Expected [mcp_servers.mousemux] in config.toml.'
& $addCheck 'MCP approval mode is prompt' $configUsesPrompt 'critical' 'Expected default_tools_approval_mode = "prompt".'

$deviceCount = 0
$getPnpDevice = Get-Command Get-PnpDevice -ErrorAction SilentlyContinue
if ($null -ne $getPnpDevice) {
    $deviceCount = @(
        Get-PnpDevice -Class Mouse, Keyboard -PresentOnly -ErrorAction SilentlyContinue
    ).Count
}
& $addCheck 'Physical input devices detected' ($deviceCount -ge 2) 'warning' ("Count={0}" -f $deviceCount)

$reportPathFull = [IO.Path]::GetFullPath($ReportPath)
$reportDirectory = Split-Path -Parent $reportPathFull
[void](New-Item -ItemType Directory -Path $reportDirectory -Force)
$report = [ordered]@{
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    computerName = $env:COMPUTERNAME
    checks = @($checks)
    criticalFailures = @($checks | Where-Object { $_.severity -eq 'critical' -and -not $_.passed }).Count
    warningFailures = @($checks | Where-Object { $_.severity -eq 'warning' -and -not $_.passed }).Count
}
[IO.File]::WriteAllText(
    $reportPathFull,
    ($report | ConvertTo-Json -Depth 8),
    [Text.UTF8Encoding]::new($false)
)

$checks |
    Select-Object name, passed, severity, detail |
    Format-Table -AutoSize

Write-Host "Verification report: $reportPathFull"
Write-Host 'Manual gates remain: cursor color, window lock, Arm MCP state, independent typing, and emergency exit.'

if ($Strict -and $report.criticalFailures -gt 0) {
    exit 1
}
