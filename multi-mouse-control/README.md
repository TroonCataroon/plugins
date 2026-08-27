# Multi Mouse Control

A Windows setup package and Cursor plugin for running an independent physical mouse and keyboard alongside a MouseMux virtual user exposed through Input Mapper MCP.

The intended result is:

```text
Physical mouse and keyboard
        |
        v
Troon seat, cyan, normal desktop access

Input Mapper MCP on localhost
        |
        v
Agent seat, magenta, locked to one approved window
```

## Safety model

This package deliberately separates convenience from containment.

- MouseMux's built-in `Ctrl+Alt+F12` exit is the primary emergency control.
- The desktop shortcut named `FORCE STOP - MouseMux` is a separate fallback that is non-elevated.
- The fallback runs only as the signed-in user and stops only processes that pass strict MouseMux path and ownership checks.
- A process is never stopped merely because it owns TCP port `41760`.
- The MCP URL must use `127.0.0.1`, `localhost`, or `::1` on port `41760`.
- Codex starts with prompt approval for MouseMux tools.
- Input Mapper **Arm MCP** remains off until the virtual cursor is visibly locked to a disposable test window.
- Window locking is an input-routing boundary, not a Windows security boundary.

Read [docs/SECURITY.md](docs/SECURITY.md) before enabling live actuation.

## Included components

- Pinned MouseMux V3 `3.0.19` installer download from the official MouseMux file host
- Authenticode signature validation before launch
- Per-user support files under `%LOCALAPPDATA%\Troon\MultiMouseControl`
- Current-user emergency fallback shortcut
- Loopback-only Codex MCP configuration writer with backup and atomic replacement
- Physical input-device inventory
- Disposable Notepad agent sandbox launcher
- Automated verification report
- Manual acceptance test
- Cursor skill and read-only setup auditor

## Requirements

- Windows 10 or Windows 11
- MouseMux V3 with the Input Mapper application available
- Codex, Cursor, or ChatGPT desktop when using the local MCP configuration
- PowerShell 5.1 or newer for installation
- Administrator approval only when the official MouseMux installer itself requests it

The support package does not create an elevated scheduled task. ChatGPT web does not read the local Codex MCP configuration. Use the desktop application, Codex CLI, or an IDE integration that reads `~/.codex/config.toml`.

## Install

Extract the package to a local directory. Open PowerShell in that directory and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Install-MultiMouseControl.ps1
```

The script copies the support package into the current user's local application data, downloads the pinned official installer, verifies its Authenticode signature, creates the current-user fallback shortcut, and opens the MouseMux installer. The shortcut is non-elevated. The third-party installer handles any administrator prompt that it requires.

To install only the support package when MouseMux is already installed:

```powershell
.\scripts\Install-MultiMouseControl.ps1 -SkipMouseMuxInstaller
```

## Configure MouseMux

Use [docs/MOUSEMUX-UI-SETUP.md](docs/MOUSEMUX-UI-SETUP.md) for the UI assignments.

Default seat plan:

| Seat | Type | Cursor | Access |
|---|---|---:|---|
| Troon | Physical | Cyan | Normal desktop |
| Agent | Virtual MCP | Magenta | Must be locked to an approved window |
| Cursor | Optional | Green | Unassigned until needed |

Start with **Switched mode** and enable **Multi Keyboard**. Do not begin with the more permissive simultaneous modes.

## Create the first sandbox

Run:

```powershell
& "$env:LOCALAPPDATA\Troon\MultiMouseControl\scripts\Start-AgentSandbox.ps1"
```

Lock the magenta Agent virtual user to the Notepad window that opens.

## Configure Input Mapper MCP

1. Open Input Mapper from MouseMux.
2. Enable MCP.
3. Keep **Arm MCP** off.
4. Copy the exact localhost URL displayed by Input Mapper.
5. Run:

```powershell
& "$env:LOCALAPPDATA\Troon\MultiMouseControl\scripts\Configure-MouseMuxMcp.ps1" `
  -Url "http://127.0.0.1:41760/mcp" `
  -VerifyWithCodex
```

The script creates a timestamped backup of `~/.codex/config.toml`, removes any stale MouseMux namespace, and writes one current server block:

```toml
[mcp_servers.mousemux]
url = "http://127.0.0.1:41760/mcp"
enabled = true
required = false
startup_timeout_sec = 10
tool_timeout_sec = 60
default_tools_approval_mode = "prompt"
```

Do not guess an `enabled_tools` allowlist. First inspect the tools exposed by the installed Input Mapper version. Then rerun the configuration script with only the approved tool names:

```powershell
& "$env:LOCALAPPDATA\Troon\MultiMouseControl\scripts\Configure-MouseMuxMcp.ps1" `
  -Url "http://127.0.0.1:41760/mcp" `
  -EnabledTool "approved_tool_one", "approved_tool_two"
```

Tool names are validated before they are written to TOML. Newlines, quotes, brackets, whitespace, and other configuration-injection characters are rejected.

## Verify

Run automated checks:

```powershell
& "$env:LOCALAPPDATA\Troon\MultiMouseControl\scripts\Discover-InputDevices.ps1"
& "$env:LOCALAPPDATA\Troon\MultiMouseControl\scripts\Verify-MultiMouseControl.ps1"
```

The verifier checks that no retired elevated task remains, the fallback shortcut targets PowerShell directly, the MCP endpoint is loopback-only, approval mode is prompt, and any process on port `41760` has a trusted MouseMux identity owned by the signed-in user.

Then complete every step in [docs/ACCEPTANCE-TEST.md](docs/ACCEPTANCE-TEST.md). Automated checks cannot prove cursor color, physical device assignment, window locking, or the current Arm MCP state.

## Emergency controls

### Primary

Press `Ctrl+Alt+F12`. This is MouseMux's own emergency exit.

### Current-user fallback

Double-click `FORCE STOP - MouseMux` on the desktop.

The fallback intentionally does not elevate. This prevents a user-writable script from becoming a persistent administrator execution path. It:

1. Enumerates Windows processes.
2. Requires an exact known MouseMux executable name.
3. Requires an exact `MouseMux`, `MouseMux V3`, or `MouseMuxV3` path segment.
4. Requires the process to be owned by the signed-in user.
5. Refuses to stop an unknown or other-user process on port `41760`.
6. Writes an audit log under `%LOCALAPPDATA%\Troon\MultiMouseControl\logs`.

If the fallback cannot stop a process because it belongs to another account or requires greater privileges, use Windows Task Manager with explicit administrator approval after inspecting the process path and publisher.

## Remove

Remove the support package and its Codex configuration:

```powershell
& "$env:LOCALAPPDATA\Troon\MultiMouseControl\scripts\Uninstall-MultiMouseControl.ps1" `
  -RemoveMcpConfiguration
```

This removes the shortcut, support files, and MouseMux MCP block. It also attempts to remove the retired `MultiMouseControl-ForceStop` task if an earlier prerelease created it. Failure to remove that legacy task produces a warning instead of silently elevating. The third-party MouseMux application is not uninstalled.

## Development tests

The repository uses Pester `5.7.1` on a Windows GitHub runner:

```powershell
Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser
.\scripts\Invoke-Tests.ps1
```

Tests cover loopback URL validation, canonical path containment, Codex TOML replacement and idempotence, tool-name injection rejection, fail-closed process identity, required package files, manifest wiring, installer pinning, non-elevated shortcut behavior, and security documentation.
