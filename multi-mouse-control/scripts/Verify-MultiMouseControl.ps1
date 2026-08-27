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

function Get-MmcProcessOwnerName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ProcessRecord
    )

    try {
        $ownerResult = Invoke-CimMethod -InputObject $ProcessRecord -MethodName GetOwner -ErrorAction Stop
        if ($ownerResult.ReturnValue -ne 0 -or [string]::IsNullOrWhiteSpace([string]$ownerResult.User)) {
            return $null
        }

        if ([string]::IsNullOrWhiteSpace([string]$ownerResult.Domain)) {
            return [string]$ownerResult.User
        }

        return '{0}\{1}' -f $ownerResult.Domain, $ownerResult.User
    } catch {
        return $null
    }
}

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

$installRootFull = [System.IO.Path]::GetFullPath($InstallRoot)
& $addCheck 'Package install root' (Test-Path -LiteralPath $installRootFull) 'critical' $installRootFull

$corePath = Join-Path $installRootFull 'scripts\MultiMouseControl.Core.psm1'
& $addCheck 'Core module installed' (Test-Path -LiteralPath $corePath) 'critical' $corePath

$legacyTaskExists = $false
$getScheduledTask = Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue
if ($null -ne $getScheduledTask) {
    try {
        $legacyTaskExists = $null -ne (Get-ScheduledTask -TaskName 'MultiMouseControl-ForceStop' -ErrorAction SilentlyContinue)
    } catch {
        $legacyTaskExists = $false
    }
}
& $addCheck 'Legacy elevated force-stop task absent' (-not $legacyTaskExists) 'critical' 'The retired MultiMouseControl-ForceStop scheduled task must not remain registered.'

$shortcutPath = Join-Path ([System.Environment]::GetFolderPath('Desktop')) 'FORCE STOP - MouseMux.lnk'
$shortcutExists = Test-Path -LiteralPath $shortcutPath
& $addCheck 'Force-stop desktop shortcut' $shortcutExists 'warning' $shortcutPath

$shortcutValid = $false
$shortcutDetail = 'Shortcut is missing.'
if ($shortcutExists) {
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $targetName = [System.IO.Path]::GetFileName([string]$shortcut.TargetPath)
        $arguments = [string]$shortcut.Arguments
        $shortcutValid = (
            $targetName -eq 'powershell.exe' -and
            $arguments -match 'Force-Stop-MouseMux\.ps1' -and
            $arguments -notmatch 'schtasks\.exe'
        )
        $shortcutDetail = "Target=$($shortcut.TargetPath); Arguments=$arguments"
    } catch {
        $shortcutDetail = "Shortcut could not be inspected: $($_.Exception.Message)"
    }
}
& $addCheck 'Force-stop shortcut is non-elevated' $shortcutValid 'critical' $shortcutDetail

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

$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$verifiedProcesses = @(
    foreach ($process in $processes) {
        $identityParameters = @{
            Name = [string]$process.Name
            ExecutablePath = [string]$process.ExecutablePath
            CommandLine = [string]$process.CommandLine
        }
        if (-not (Test-MouseMuxProcessIdentity @identityParameters)) {
            continue
        }

        $ownerName = Get-MmcProcessOwnerName -ProcessRecord $process
        if (-not [string]::IsNullOrWhiteSpace($ownerName) -and $ownerName.Equals($currentIdentity, [System.StringComparison]::OrdinalIgnoreCase)) {
            $process
        }
    }
)
& $addCheck 'Verified current-user MouseMux process running' ($verifiedProcesses.Count -gt 0) 'warning' ("Count={0}" -f $verifiedProcesses.Count)

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

$verifiedProcessIds = [System.Collections.Generic.HashSet[int]]::new()
foreach ($process in $verifiedProcesses) {
    [void]$verifiedProcessIds.Add([int]$process.ProcessId)
}
$allListenersVerified = $listenerPids.Count -gt 0
foreach ($listenerPid in $listenerPids) {
    if (-not $verifiedProcessIds.Contains([int]$listenerPid)) {
        $allListenersVerified = $false
    }
}
& $addCheck 'MCP port owner identity verified' $allListenersVerified 'critical' 'Every listener on port 41760 must be a verified current-user MouseMux process.'

$configExists = Test-Path -LiteralPath $ConfigPath
& $addCheck 'Codex configuration exists' $configExists 'warning' $ConfigPath
$configHasMouseMux = $false
$configUsesPrompt = $false
$configEndpointValid = $false
$configEndpointDetail = 'MouseMux MCP block was not found.'
if ($configExists) {
    $configContent = [System.IO.File]::ReadAllText([System.IO.Path]::GetFullPath($ConfigPath))
    $blockMatch = [regex]::Match(
        $configContent,
        '(?ms)^\s*\[mcp_servers\.mousemux\]\s*(?<body>.*?)(?=^\s*\[|\z)'
    )
    $configHasMouseMux = $blockMatch.Success
    if ($blockMatch.Success) {
        $blockBody = $blockMatch.Groups['body'].Value
        $configUsesPrompt = $blockBody -match '(?m)^\s*default_tools_approval_mode\s*=\s*"prompt"\s*$'
        $urlMatch = [regex]::Match($blockBody, '(?m)^\s*url\s*=\s*"(?<url>[^"]+)"\s*$')
        if ($urlMatch.Success) {
            try {
                $resolvedUri = Resolve-MmcMcpUri -Url $urlMatch.Groups['url'].Value
                $configEndpointValid = $true
                $configEndpointDetail = $resolvedUri.AbsoluteUri
            } catch {
                $configEndpointDetail = $_.Exception.Message
            }
        } else {
            $configEndpointDetail = 'MouseMux MCP URL was not found.'
        }
    }
}
& $addCheck 'MouseMux MCP configured' $configHasMouseMux 'critical' 'Expected [mcp_servers.mousemux] in config.toml.'
& $addCheck 'MouseMux MCP endpoint is loopback-only' $configEndpointValid 'critical' $configEndpointDetail
& $addCheck 'MCP approval mode is prompt' $configUsesPrompt 'critical' 'Expected default_tools_approval_mode = "prompt".'

$deviceCount = 0
$getPnpDevice = Get-Command Get-PnpDevice -ErrorAction SilentlyContinue
if ($null -ne $getPnpDevice) {
    $deviceCount = @(
        Get-PnpDevice -Class Mouse, Keyboard -PresentOnly -ErrorAction SilentlyContinue
    ).Count
}
& $addCheck 'Physical input devices detected' ($deviceCount -ge 2) 'warning' ("Count={0}" -f $deviceCount)

$reportPathFull = [System.IO.Path]::GetFullPath($ReportPath)
$reportDirectory = Split-Path -Parent $reportPathFull
[void](New-Item -ItemType Directory -Path $reportDirectory -Force)
$report = [ordered]@{
    generatedAtUtc = [System.DateTime]::UtcNow.ToString('o')
    computerName = $env:COMPUTERNAME
    checks = @($checks)
    criticalFailures = @($checks | Where-Object { $_.severity -eq 'critical' -and -not $_.passed }).Count
    warningFailures = @($checks | Where-Object { $_.severity -eq 'warning' -and -not $_.passed }).Count
}
[System.IO.File]::WriteAllText(
    $reportPathFull,
    ($report | ConvertTo-Json -Depth 8),
    [System.Text.UTF8Encoding]::new($false)
)

$checks |
    Select-Object name, passed, severity, detail |
    Format-Table -AutoSize

Write-Host "Verification report: $reportPathFull"
Write-Host 'Manual gates remain: cursor color, window lock, Arm MCP state, independent typing, and emergency exit.'

if ($Strict -and $report.criticalFailures -gt 0) {
    exit 1
}
