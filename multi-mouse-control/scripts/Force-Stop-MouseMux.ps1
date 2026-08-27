#requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$Port = 41760,

    [string]$LogPath = $(Join-Path $env:ProgramData 'Troon\MultiMouseControl\logs\force-stop.log'),

    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'MultiMouseControl.Core.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

$timestamp = [DateTime]::UtcNow.ToString('o')
$messages = [System.Collections.Generic.List[string]]::new()
$trustedProcessIds = [System.Collections.Generic.HashSet[int]]::new()

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
    $trusted = Test-MouseMuxProcessIdentity @identityParameters

    if ($trusted) {
        [void]$trustedProcessIds.Add([int]$process.ProcessId)
    }
}

$listenerProcessIds = @()
try {
    $listenerProcessIds = @(
        Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop |
            Select-Object -ExpandProperty OwningProcess -Unique
    )
} catch {
    $messages.Add("$timestamp WARN Unable to inspect TCP port $Port: $($_.Exception.Message)")
}

foreach ($listenerPid in $listenerProcessIds) {
    $listenerProcess = $processes | Where-Object { [int]$_.ProcessId -eq [int]$listenerPid } | Select-Object -First 1
    if ($null -eq $listenerProcess) {
        $messages.Add("$timestamp WARN Port $Port is owned by PID $listenerPid, but its process identity could not be read. It was not stopped.")
        continue
    }

    $listenerIdentityParameters = @{
        Name = [string]$listenerProcess.Name
        ExecutablePath = [string]$listenerProcess.ExecutablePath
        CommandLine = [string]$listenerProcess.CommandLine
    }
    $listenerIsMouseMux = Test-MouseMuxProcessIdentity @listenerIdentityParameters

    if ($listenerIsMouseMux) {
        [void]$trustedProcessIds.Add([int]$listenerPid)
    } else {
        $messages.Add("$timestamp WARN Port $Port is owned by unverified process '$($listenerProcess.Name)' PID $listenerPid. It was not stopped.")
    }
}

if ($trustedProcessIds.Count -eq 0) {
    $messages.Add("$timestamp INFO No verified MouseMux process was running.")
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
        $messages.Add("$timestamp ERROR Failed to stop $processName PID $processId: $($_.Exception.Message)")
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
