#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$InstallRoot = $(Join-Path $env:LOCALAPPDATA 'Troon\MultiMouseControl'),

    [string]$ConfigPath = $(Join-Path $env:USERPROFILE '.codex\config.toml'),

    [switch]$RemoveMcpConfiguration,

    [switch]$KeepInstalledFiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'Multi Mouse Control can only be uninstalled on Windows.'
}

$modulePath = Join-Path $PSScriptRoot 'MultiMouseControl.Core.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

$installRootFull = [System.IO.Path]::GetFullPath($InstallRoot)
$localAppDataFull = [System.IO.Path]::GetFullPath($env:LOCALAPPDATA)
if (-not (Test-MmcPathWithinRoot -Path $installRootFull -Root $localAppDataFull)) {
    throw 'Refusing to remove an InstallRoot outside LOCALAPPDATA.'
}

$trimCharacters = [char[]]@(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$trimmedInstallRoot = $installRootFull.TrimEnd($trimCharacters)
if ([System.IO.Path]::GetFileName($trimmedInstallRoot) -ne 'MultiMouseControl') {
    throw 'Refusing to remove an InstallRoot whose final directory is not MultiMouseControl.'
}

$legacyTaskName = 'MultiMouseControl-ForceStop'
$getScheduledTask = Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue
$unregisterScheduledTask = Get-Command Unregister-ScheduledTask -ErrorAction SilentlyContinue
if ($null -ne $getScheduledTask -and $null -ne $unregisterScheduledTask) {
    try {
        $legacyTask = Get-ScheduledTask -TaskName $legacyTaskName -ErrorAction SilentlyContinue
        if ($null -ne $legacyTask) {
            Unregister-ScheduledTask -TaskName $legacyTaskName -Confirm:$false -ErrorAction Stop
            Write-Host "Removed legacy scheduled task: $legacyTaskName"
        }
    } catch {
        Write-Warning "A legacy elevated task may still exist and could not be removed without administrator approval: $($_.Exception.Message)"
    }
}

$shortcutPath = Join-Path ([System.Environment]::GetFolderPath('Desktop')) 'FORCE STOP - MouseMux.lnk'
if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
    Write-Host "Removed shortcut: $shortcutPath"
}

if ($RemoveMcpConfiguration -and (Test-Path -LiteralPath $ConfigPath)) {
    $configPathFull = [System.IO.Path]::GetFullPath($ConfigPath)
    $currentContent = [System.IO.File]::ReadAllText($configPathFull)
    $updatedContent = Remove-CodexMouseMuxBlock -Content $currentContent
    if (-not [string]::IsNullOrWhiteSpace($updatedContent)) {
        $updatedContent = $updatedContent.TrimEnd() + "`n"
    }

    if ($updatedContent -ne $currentContent) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        $backupPath = "$configPathFull.multi-mouse-control-uninstall.$timestamp.bak"
        Copy-Item -LiteralPath $configPathFull -Destination $backupPath -Force
        [System.IO.File]::WriteAllText(
            $configPathFull,
            $updatedContent,
            [System.Text.UTF8Encoding]::new($false)
        )
        Write-Host "Removed MouseMux MCP configuration. Backup: $backupPath"
    }
}

if (-not $KeepInstalledFiles -and (Test-Path -LiteralPath $installRootFull)) {
    $escapedRoot = $installRootFull.Replace("'", "''")
    $cleanupScript = "Start-Sleep -Seconds 2; Remove-Item -LiteralPath '$escapedRoot' -Recurse -Force"
    $encodedCleanup = [System.Convert]::ToBase64String(
        [System.Text.Encoding]::Unicode.GetBytes($cleanupScript)
    )
    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-EncodedCommand',
        $encodedCleanup
    )
    Write-Host "Scheduled package directory removal: $installRootFull"
}

Write-Host ''
Write-Host 'Multi Mouse Control support files were removed.' -ForegroundColor Green
Write-Host 'The third-party MouseMux application was not uninstalled.'
Write-Host 'Use Windows Installed apps if you also intend to remove MouseMux.'
