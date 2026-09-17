param(
    [string]$Upstream = (Join-Path (Split-Path -Parent $PSScriptRoot) ".upstream\blender-agent-studio")
)

$ErrorActionPreference = "Stop"
$Server = Join-Path $Upstream "plugins\blender-agent-studio\mcp\server.ts"

if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    throw "Bun is required. Run sync-upstream.ps1 after installing Bun 1.3.5+."
}
if (-not (Test-Path $Server)) {
    throw "Pinned upstream checkout is missing. Run scripts\sync-upstream.ps1 first."
}
if (-not $env:BLENDER_EXECUTABLE -and -not (Get-Command blender -ErrorAction SilentlyContinue)) {
    Write-Warning "Blender is not on PATH and BLENDER_EXECUTABLE is not set. Blender-backed tools will fail until configured."
}

& bun $Server
exit $LASTEXITCODE
