#requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$Port = 41760,

    [string]$LogPath = $(Join-Path $env:LOCALAPPDATA 'Troon\MultiMouseControl\logs\force-stop.log'),

    [switch]$Quiet
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

$timestamp = [System.DateTime]::UtcNow.ToString('o')
$messages = [System.Collections.Generic.List[string]]::new()
$trustedProcessIds = [System.Collections.Generic.HashSet[int]]::new()
$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

try {
    $processes = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)
} catch {
    $processes = @()
    $messages.Add("$timestamp ERROR Unable to enumerate Windows processes: $($_.Exception.Message)")
}

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
    if ([string]::IsNullOrWhiteSpace($ownerName)) {
        $messages.Add("$timestamp WARN Verified MouseMux identity PID $($process.ProcessId) has an unreadable owner. It was not stopped.")
        continue
    }

    if (-not $ownerName.Equals($currentIdentity, [System.StringComparison]::OrdinalIgnoreCase)) {
        $messages.Add("$timestamp WARN Verified MouseMux identity PID $($process.ProcessId) belongs to '$ownerName', not '$currentIdentity'. It was not stopped.")
        continue
    }

    [void]$trustedProcessIds.Add([int]$process.ProcessId)
}

$listenerProcessIds = @()
try {
    $listenerProcessIds = @(
        Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop |
            Select-Object -ExpandProperty OwningProcess -Unique
    )
} catch {
    $messages.Add("$timestamp WARN Unable to inspect TCP port ${Port}: $($_.Exception.Message)")
}

foreach ($listenerPid in $listenerProcessIds) {
    if (-not $trustedProcessIds.Contains([int]$listenerPid)) {
        $listenerProcess = $processes | Where-Object { [int]$_.ProcessId -eq [int]$listenerPid } | Select-Object -First 1
        $listenerName = if ($null -ne $listenerProcess) { [string]$listenerProcess.Name } else { 'unknown' }
        $messages.Add("$timestamp WARN Port $Port is owned by unverified or other-user process '$listenerName' PID $listenerPid. It was not stopped.")
    }
}

if ($trustedProcessIds.Count -eq 0) {
    $messages.Add("$timestamp INFO No verified current-user MouseMux process was running.")
}

foreach ($processId in @($trustedProcessIds)) {
    $processRecord = $processes | Where-Object { [int]$_.ProcessId -eq $processId } | Select-Object -First 1
    $processName = if ($null -ne $processRecord) { [string]$processRecord.Name } else { 'verified MouseMux process' }

    try {
        Stop-Process -Id $processId -Force -ErrorAction Stop
        Start-Sleep -Milliseconds 250

        if (Get-Process -Id $processId -ErrorAction SilentlyContinue) {
            & taskkill.exe /PID $processId /T /F | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "taskkill exited with code $LASTEXITCODE"
            }
        }

        $messages.Add("$timestamp INFO Stopped $processName PID $processId.")
    } catch {
        $messages.Add("$timestamp ERROR Failed to stop $processName PID ${processId}: $($_.Exception.Message)")
    }
}

$logDirectory = Split-Path -Parent $LogPath
if (-not [string]::IsNullOrWhiteSpace($logDirectory)) {
    [void](New-Item -ItemType Directory -Path $logDirectory -Force)
}
$messages | Add-Content -LiteralPath $LogPath -Encoding UTF8

if (-not $Quiet) {
    foreach ($message in $messages) {
        if ($message -match ' ERROR ') {
            Write-Host $message -ForegroundColor Red
        } elseif ($message -match ' WARN ') {
            Write-Host $message -ForegroundColor Yellow
        } else {
            Write-Host $message
        }
    }
}
