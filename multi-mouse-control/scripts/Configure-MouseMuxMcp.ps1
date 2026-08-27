#requires -Version 5.1

[CmdletBinding(DefaultParameterSetName = 'Set')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Set')]
    [ValidateNotNullOrEmpty()]
    [string]$Url,

    [Parameter(Mandatory, ParameterSetName = 'Remove')]
    [switch]$Remove,

    [string[]]$EnabledTool,

    [string]$ConfigPath = $(Join-Path $env:USERPROFILE '.codex\config.toml'),

    [switch]$NoBackup,

    [switch]$VerifyWithCodex
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'MultiMouseControl.Core.psm1'
Import-Module $modulePath -Force -ErrorAction Stop

$configPathFull = [IO.Path]::GetFullPath($ConfigPath)
$configDirectory = Split-Path -Parent $configPathFull
if ([string]::IsNullOrWhiteSpace($configDirectory)) {
    throw 'ConfigPath must include a parent directory.'
}

[void](New-Item -ItemType Directory -Path $configDirectory -Force)
$currentContent = if (Test-Path -LiteralPath $configPathFull) {
    [IO.File]::ReadAllText($configPathFull)
} else {
    ''
}

if ($PSCmdlet.ParameterSetName -eq 'Remove') {
    $updatedContent = Remove-CodexMouseMuxBlock -Content $currentContent
    if (-not [string]::IsNullOrWhiteSpace($updatedContent)) {
        $updatedContent = $updatedContent.TrimEnd() + "`n"
    }
} else {
    $validatedUri = Resolve-MmcMcpUri -Url $Url
    $setParameters = @{
        Content = $currentContent
        Url = $validatedUri.AbsoluteUri
        EnabledTool = $EnabledTool
    }
    $updatedContent = Set-CodexMouseMuxBlock @setParameters
}

if ($updatedContent -eq $currentContent) {
    Write-Host 'Codex configuration already matches the requested state.' -ForegroundColor Green
    return
}

$backupPath = $null
if (-not $NoBackup -and (Test-Path -LiteralPath $configPathFull)) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $backupPath = "$configPathFull.multi-mouse-control.$timestamp.bak"
    Copy-Item -LiteralPath $configPathFull -Destination $backupPath -Force
}

$tempPath = Join-Path $configDirectory ('.config.toml.{0}.tmp' -f [Guid]::NewGuid().ToString('N'))
try {
    [IO.File]::WriteAllText($tempPath, $updatedContent, [Text.UTF8Encoding]::new($false))

    if (Test-Path -LiteralPath $configPathFull) {
        [IO.File]::Replace($tempPath, $configPathFull, $null)
    } else {
        Move-Item -LiteralPath $tempPath -Destination $configPathFull
    }
} finally {
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    }
}

if ($PSCmdlet.ParameterSetName -eq 'Remove') {
    Write-Host 'Removed the MouseMux MCP namespace from the Codex configuration.' -ForegroundColor Green
} else {
    Write-Host 'Configured the MouseMux MCP endpoint with prompt approval by default.' -ForegroundColor Green
    Write-Host "Endpoint: $($validatedUri.AbsoluteUri)"
}
Write-Host "Config: $configPathFull"
if ($null -ne $backupPath) {
    Write-Host "Backup: $backupPath"
}

if ($VerifyWithCodex) {
    $codexCommand = Get-Command codex -ErrorAction SilentlyContinue
    if ($null -eq $codexCommand) {
        Write-Warning 'Codex CLI is not available on PATH, so codex mcp list was not run.'
    } else {
        & $codexCommand.Source mcp list
        if ($LASTEXITCODE -ne 0) {
            throw "codex mcp list failed with exit code $LASTEXITCODE."
        }
    }
}
