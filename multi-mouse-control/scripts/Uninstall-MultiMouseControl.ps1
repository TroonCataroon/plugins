#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$InstallRoot = $(Join-Path $env:LOCALAPPDATA 'Troon\MultiMouseControl'),

    [string]$ConfigPath = $(Join-Path $env:USERPROFILE '.codex\config.toml'),

    [switch]$RemoveMcpConfiguration,

    [switch]$KeepInstalledFiles,

    [Parameter(DontShow)]
    [switch]$Elevated
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'Multi Mouse Control can only be uninstalled on Windows.'
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdministrator) {
    if ($Elevated) {
        throw 'Elevation was requested, but the process is not running as an administrator.'
    }

    $quotedScript = '"{0}"' -f $PSCommandPath.Replace('"', '\"')
    $quotedInstallRoot = '"{0}"' -f $InstallRoot.Replace('"', '\"')
    $quotedConfigPath = '"{0}"' -f $ConfigPath.Replace('"', '\"')
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy Bypass',
        '-File',
        $quotedScript,
        '-InstallRoot',
        $quotedInstallRoot,
        '-ConfigPath',
        $quotedConfigPath,
        '-Elevated'
    )
    if ($RemoveMcpConfiguration) { $arguments += '-RemoveMcpConfiguration' }
    if ($KeepInstalledFiles) { $arguments += '-KeepInstalledFiles' }

    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ($arguments -join ' ')
    return
}

$installRootFull = [IO.Path]::GetFullPath($InstallRoot)
$localAppDataFull = [IO.Path]::GetFullPath($env:LOCALAPPDATA)
if (-not $installRootFull.StartsWith($localAppDataFull, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to remove an InstallRoot outside LOCALAPPDATA.'
}
$trimmedInstallRoot = $installRootFull.TrimEnd([char[]]@([char]92, [char]47))
if ([IO.Path]::GetFileName($trimmedInstallRoot) -ne 'MultiMouseControl') {
    throw 'Refusing to remove an InstallRoot whose final directory is not MultiMouseControl.'
}

$taskName = 'MultiMouseControl-ForceStop'
try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
    Write-Host "Removed scheduled task: $taskName"
} catch {
    Write-Verbose "Scheduled task was not present or could not be removed: $($_.Exception.Message)"
}

$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'FORCE STOP - MouseMux.lnk'
if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
    Write-Host "Removed shortcut: $shortcutPath"
}

if ($RemoveMcpConfiguration -and (Test-Path -LiteralPath $ConfigPath)) {
    $moduleCandidates = @(
        (Join-Path $installRootFull 'scripts\MultiMouseControl.Core.psm1'),
        (Join-Path $PSScriptRoot 'MultiMouseControl.Core.psm1')
    )
    $modulePath = $moduleCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($null -eq $modulePath) {
        throw 'Cannot remove the Codex MCP block because MultiMouseControl.Core.psm1 was not found.'
    }

    Import-Module $modulePath -Force -ErrorAction Stop
    $configPathFull = [IO.Path]::GetFullPath($ConfigPath)
    $currentContent = [IO.File]::ReadAllText($configPathFull)
    $updatedContent = Remove-CodexMouseMuxBlock -Content $currentContent
    if (-not [string]::IsNullOrWhiteSpace($updatedContent)) {
        $updatedContent = $updatedContent.TrimEnd() + "`n"
    }

    if ($updatedContent -ne $currentContent) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        $backupPath = "$configPathFull.multi-mouse-control-uninstall.$timestamp.bak"
        Copy-Item -LiteralPath $configPathFull -Destination $backupPath -Force
        [IO.File]::WriteAllText($configPathFull, $updatedContent, [Text.UTF8Encoding]::new($false))
        Write-Host "Removed MouseMux MCP configuration. Backup: $backupPath"
    }
}

if (-not $KeepInstalledFiles -and (Test-Path -LiteralPath $installRootFull)) {
    $escapedRoot = $installRootFull.Replace("'", "''")
    $cleanupScript = "Start-Sleep -Seconds 2; Remove-Item -LiteralPath '$escapedRoot' -Recurse -Force"
    $encodedCleanup = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cleanupScript))
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
