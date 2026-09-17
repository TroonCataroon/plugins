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
    [Console]::Error.WriteLine("Warning: Blender is not on PATH and BLENDER_EXECUTABLE is not set. Blender-backed tools will fail until configured.")
}

# Do not wrap bun through PowerShell's native-command encoder. Windows
# PowerShell 5.1 is not a transparent stdio proxy: it can re-encode UTF-8
# and leak host/warning output into the JSON-RPC channel ChatGPT uses.
# Start bun with inherited handles so it owns stdin/stdout, matching the
# Unix launcher's `exec bun`.
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = (Get-Command bun).Source
$startInfo.Arguments = "`"$Server`""
$startInfo.UseShellExecute = $false
$process = New-Object System.Diagnostics.Process
$process.StartInfo = $startInfo
[void]$process.Start()
$process.WaitForExit()
exit $process.ExitCode
