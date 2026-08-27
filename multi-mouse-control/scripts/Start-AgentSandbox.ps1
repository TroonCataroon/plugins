#requires -Version 5.1

[CmdletBinding()]
param(
    [string]$SandboxRoot = $(Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'AgentSandbox'),

    [string]$SeatName = 'Agent',

    [switch]$NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'The agent sandbox launcher requires Windows.'
}

$sandboxRootFull = [IO.Path]::GetFullPath($SandboxRoot)
[void](New-Item -ItemType Directory -Path $sandboxRootFull -Force)

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$fileName = 'AGENT-SANDBOX-{0}.txt' -f $timestamp
$filePath = Join-Path $sandboxRootFull $fileName
$titleMarker = 'MOUSEMUX AGENT SANDBOX'

$content = @"
$titleMarker

Virtual seat: $SeatName
Created: $([DateTime]::Now.ToString('o'))

BOUNDARY
This Notepad window is the only permitted pointer and keyboard target during the first acceptance test.
Do not interact with administrator prompts, credential dialogs, financial applications, production systems, or any other window.
Do not enable Arm MCP until the virtual cursor is visibly locked to this window.

TEST STEPS
1. Lock the $SeatName virtual user to this Notepad window in MouseMux.
2. Move the physical mouse and confirm its cursor remains independent.
3. Arm MCP in Input Mapper.
4. Ask the agent to type exactly: MOUSEMUX ACCEPTANCE TEST PASSED
5. Confirm no input reaches another window.
6. Disarm MCP immediately after the test.
"@

[IO.File]::WriteAllText($filePath, $content, [Text.UTF8Encoding]::new($false))
$process = $null
if (-not $NoLaunch) {
    $quotedFilePath = '"{0}"' -f $filePath.Replace('"', '\"')
    $process = Start-Process -FilePath 'notepad.exe' -ArgumentList $quotedFilePath -PassThru
}

$stateRoot = Join-Path $env:LOCALAPPDATA 'Troon\MultiMouseControl\state'
[void](New-Item -ItemType Directory -Path $stateRoot -Force)
$statePath = Join-Path $stateRoot 'agent-sandbox-target.json'
$state = [ordered]@{
    seatName = $SeatName
    targetFile = $filePath
    titleMarker = $titleMarker
    processId = if ($null -ne $process) { $process.Id } else { $null }
    createdAtUtc = [DateTime]::UtcNow.ToString('o')
    actuationExpected = $false
}
[IO.File]::WriteAllText(
    $statePath,
    ($state | ConvertTo-Json -Depth 4),
    [Text.UTF8Encoding]::new($false)
)

Write-Host "Agent sandbox created: $filePath" -ForegroundColor Green
Write-Host 'Keep Arm MCP off until the virtual cursor is visibly locked to this window.'
Write-Output $filePath
