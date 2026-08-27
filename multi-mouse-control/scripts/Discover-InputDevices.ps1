#requires -Version 5.1

[CmdletBinding()]
param(
    [string]$OutputPath = $(Join-Path $env:LOCALAPPDATA 'Troon\MultiMouseControl\state\input-devices.json'),

    [switch]$IncludeDisconnected
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'Input device discovery requires Windows.'
}

$deviceRecords = [System.Collections.Generic.List[object]]::new()
$getPnpDevice = Get-Command Get-PnpDevice -ErrorAction SilentlyContinue

if ($null -ne $getPnpDevice) {
    foreach ($deviceClass in @('Mouse', 'Keyboard')) {
        $parameters = @{
            Class = $deviceClass
            ErrorAction = 'SilentlyContinue'
        }
        if (-not $IncludeDisconnected) {
            $parameters.PresentOnly = $true
        }

        foreach ($device in @(Get-PnpDevice @parameters)) {
            $deviceRecords.Add([pscustomobject][ordered]@{
                class = $deviceClass
                friendlyName = $device.FriendlyName
                instanceId = $device.InstanceId
                status = [string]$device.Status
                present = if ($device.PSObject.Properties.Name -contains 'Present') { [bool]$device.Present } else { $null }
                problem = if ($device.PSObject.Properties.Name -contains 'Problem') { [string]$device.Problem } else { $null }
                source = 'Get-PnpDevice'
            })
        }
    }
} else {
    foreach ($device in @(Get-CimInstance Win32_PointingDevice -ErrorAction SilentlyContinue)) {
        $deviceRecords.Add([pscustomobject][ordered]@{
            class = 'Mouse'
            friendlyName = $device.Name
            instanceId = $device.PNPDeviceID
            status = $device.Status
            present = $null
            problem = $null
            source = 'Win32_PointingDevice'
        })
    }

    foreach ($device in @(Get-CimInstance Win32_Keyboard -ErrorAction SilentlyContinue)) {
        $deviceRecords.Add([pscustomobject][ordered]@{
            class = 'Keyboard'
            friendlyName = $device.Name
            instanceId = $device.PNPDeviceID
            status = $device.Status
            present = $null
            problem = $null
            source = 'Win32_Keyboard'
        })
    }
}

$outputPathFull = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $outputPathFull
[void](New-Item -ItemType Directory -Path $outputDirectory -Force)

$result = [ordered]@{
    capturedAtUtc = [DateTime]::UtcNow.ToString('o')
    computerName = $env:COMPUTERNAME
    count = $deviceRecords.Count
    devices = @($deviceRecords)
}
[IO.File]::WriteAllText(
    $outputPathFull,
    ($result | ConvertTo-Json -Depth 8),
    [Text.UTF8Encoding]::new($false)
)

$deviceRecords |
    Sort-Object class, friendlyName |
    Format-Table class, friendlyName, status, instanceId -AutoSize

Write-Host "Device inventory saved: $outputPathFull" -ForegroundColor Green
