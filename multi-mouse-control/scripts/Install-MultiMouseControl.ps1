#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$InstallRoot = $(Join-Path $env:LOCALAPPDATA 'Troon\MultiMouseControl'),

    [string]$InstallerUrl = 'https://files.mousemux.com/files/setup/mousemux-v3-setup-3.0.19.exe',

    [switch]$SkipMouseMuxInstaller,

    [switch]$SkipDesktopShortcut,

    [switch]$NoLaunch,

    [switch]$ForceDownload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'Multi Mouse Control can only be installed on Windows 10 or Windows 11.'
}

$modulePath = Join-Path $PSScriptRoot 'MultiMouseControl.Core.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

$installRootFull = [System.IO.Path]::GetFullPath($InstallRoot)
$localAppDataFull = [System.IO.Path]::GetFullPath($env:LOCALAPPDATA)
if (-not (Test-MmcPathWithinRoot -Path $installRootFull -Root $localAppDataFull)) {
    throw "InstallRoot must be inside LOCALAPPDATA. Requested path: $installRootFull"
}

$trimCharacters = [char[]]@(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$installRootLeaf = [System.IO.Path]::GetFileName($installRootFull.TrimEnd($trimCharacters))
if ($installRootLeaf -ne 'MultiMouseControl') {
    throw 'InstallRoot must end with the directory name MultiMouseControl.'
}

$installerUri = $null
if (-not [System.Uri]::TryCreate($InstallerUrl, [System.UriKind]::Absolute, [ref]$installerUri)) {
    throw 'InstallerUrl must be an absolute URI.'
}

if (
    $installerUri.Scheme -ne 'https' -or
    -not $installerUri.Host.Equals('files.mousemux.com', [System.StringComparison]::OrdinalIgnoreCase) -or
    $installerUri.AbsolutePath -ne '/files/setup/mousemux-v3-setup-3.0.19.exe' -or
    -not [string]::IsNullOrEmpty($installerUri.UserInfo) -or
    -not [string]::IsNullOrEmpty($installerUri.Query) -or
    -not [string]::IsNullOrEmpty($installerUri.Fragment)
) {
    throw 'InstallerUrl must be the pinned official MouseMux V3 3.0.19 installer URL.'
}

$sourceRoot = Split-Path -Parent $PSScriptRoot
$installDirectories = @(
    $installRootFull,
    (Join-Path $installRootFull 'downloads'),
    (Join-Path $installRootFull 'state'),
    (Join-Path $installRootFull 'logs')
)
foreach ($directory in $installDirectories) {
    [void](New-Item -ItemType Directory -Path $directory -Force)
}

if (-not [System.IO.Path]::GetFullPath($sourceRoot).Equals($installRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    foreach ($itemName in @('.cursor-plugin', 'agents', 'skills', 'scripts', 'config', 'docs', 'README.md', 'CHANGELOG.md', 'LICENSE')) {
        $sourcePath = Join-Path $sourceRoot $itemName
        if (Test-Path -LiteralPath $sourcePath) {
            Copy-Item -LiteralPath $sourcePath -Destination $installRootFull -Recurse -Force
        }
    }
}

$forceStopPath = Join-Path $installRootFull 'scripts\Force-Stop-MouseMux.ps1'
$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$forceStopShortcutPath = Join-Path $desktopPath 'FORCE STOP - MouseMux.lnk'

if (-not $SkipDesktopShortcut) {
    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($forceStopShortcutPath)
    $shortcut.TargetPath = $windowsPowerShell
    $shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Quiet' -f $forceStopPath
    $shortcut.WorkingDirectory = $installRootFull
    $shortcut.Description = 'Current-user emergency fallback that stops only verified MouseMux processes.'
    $shortcut.IconLocation = (Join-Path $env:SystemRoot 'System32\shell32.dll') + ',131'
    $shortcut.Save()
}

$installerPath = Join-Path $installRootFull 'downloads\mousemux-v3-setup-3.0.19.exe'
$installerState = $null
if (-not $SkipMouseMuxInstaller) {
    if ($ForceDownload -or -not (Test-Path -LiteralPath $installerPath)) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $installerUri.AbsoluteUri -OutFile $installerPath -UseBasicParsing
    }

    $signature = Get-AuthenticodeSignature -LiteralPath $installerPath
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
        Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
        throw "The MouseMux installer Authenticode signature is not valid. Status: $($signature.Status)"
    }

    $installerHash = Get-FileHash -LiteralPath $installerPath -Algorithm SHA256
    $installerState = [ordered]@{
        url = $installerUri.AbsoluteUri
        path = $installerPath
        sha256 = $installerHash.Hash.ToLowerInvariant()
        signatureStatus = [string]$signature.Status
        signerSubject = if ($null -ne $signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
        signerThumbprint = if ($null -ne $signature.SignerCertificate) { $signature.SignerCertificate.Thumbprint } else { $null }
    }
}

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$installationState = [ordered]@{
    package = 'multi-mouse-control'
    packageVersion = '1.0.0'
    installedAtUtc = [System.DateTime]::UtcNow.ToString('o')
    installedBy = $identity.Name
    installRoot = $installRootFull
    forceStopMode = 'current-user'
    forceStopShortcut = if ($SkipDesktopShortcut) { $null } else { $forceStopShortcutPath }
    mouseMuxInstaller = $installerState
}

$statePath = Join-Path $installRootFull 'state\installation.json'
$stateJson = $installationState | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($statePath, $stateJson, [System.Text.UTF8Encoding]::new($false))

if (-not $SkipMouseMuxInstaller -and -not $NoLaunch) {
    Start-Process -FilePath $installerPath
}

Write-Host ''
Write-Host 'Multi Mouse Control package installed.' -ForegroundColor Green
Write-Host "Install root: $installRootFull"
Write-Host 'Primary MouseMux emergency exit: Ctrl+Alt+F12'
if (-not $SkipDesktopShortcut) {
    Write-Host "Current-user fallback: $forceStopShortcutPath"
}
Write-Host ''
Write-Host 'Next steps:'
Write-Host '1. Complete the official MouseMux installer.'
Write-Host '2. Configure physical and virtual users in MouseMux.'
Write-Host '3. Start Input Mapper, enable MCP, and leave Arm MCP off.'
Write-Host '4. Copy its exact localhost URL and run Configure-MouseMuxMcp.ps1.'
Write-Host '5. Run Verify-MultiMouseControl.ps1 and docs\ACCEPTANCE-TEST.md.'
