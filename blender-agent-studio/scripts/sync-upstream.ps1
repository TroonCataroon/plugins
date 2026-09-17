param(
    [string]$Destination = (Join-Path (Split-Path -Parent $PSScriptRoot) ".upstream\blender-agent-studio")
)

$ErrorActionPreference = "Stop"
$Repository = "https://github.com/ifBars/blender-agent-studio.git"
$Commit = "422dae578005e912caa745a723fc300931990164"
$PluginDir = Join-Path $Destination "plugins\blender-agent-studio"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is required."
}
if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    throw "Bun 1.3.5 or newer is required."
}

if (-not (Test-Path (Join-Path $Destination ".git"))) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    git clone $Repository $Destination
} else {
    git -C $Destination remote set-url origin $Repository
}

git -C $Destination fetch origin main --tags
git -C $Destination fetch origin $Commit
git -C $Destination checkout --detach $Commit

bun install --cwd $PluginDir

Write-Host "Pinned Blender Agent Studio ready at $Destination"
Write-Host "Commit: $Commit"
Write-Host "Next: set BLENDER_EXECUTABLE if Blender is not already on PATH."
