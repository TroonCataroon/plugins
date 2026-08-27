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
- The desktop shortcut named `FORCE STOP - MouseMux` is a separate elevated fallback.
- The fallback stops only processes that pass strict MouseMux identity checks.
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
- On-demand elevated force-stop scheduled task
- Desktop emergency fallback shortcut
- Loopback-only Codex MCP configuration writer with backup and atomic replacement
- Physical input-device inventory
- Disposable Notepad agent sandbox launcher
- Automated verification report
- Manual acceptance test
- Cursor skill and read-only setup auditor

## Requirements

- Windows 10 or Windows 11
- Administrator approval for installation and emergency task registration
- MouseMux V3 with the Input Mapper application available
- Codex, Cursor, or ChatGPT desktop when using the local MCP configuration
- PowerShell 5.1 or newer for installation

ChatGPT web does not read the local Codex MCP configuration. Use the desktop application, Codex CLI, or an IDE integration that reads `~/.codex/config.toml`.

## Install

Extract the package to a local directory. Open PowerShell in that directory and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\Install-MultiMouseControl.ps1
```

The script requests elevation, copies the support package, downloads the pinned official installer, verifies its Authenticode signature, registers the force-stop task, creates the fallback shortcut, and opens the MouseMux installer.

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

## Verify

Run automated checks:

```powershell
& "$env:LOCALAPPDATA\Troon\MultiMouseControl\scripts\Discover-InputDevices.ps1"
& "$env:LOCALAPPDATA\Troon\MultiMouseControl\scripts\Verify-MultiMouseControl.ps1"
```

Then complete every step in [docs/ACCEPTANCE-TEST.md](docs/ACCEPTANCE-TEST.md). Automated checks cannot prove cursor color, physical device assignment, window locking, or the current Arm MCP state.

## Emergency controls

### Primary

Press `Ctrl+Alt+F12`. This is MouseMux's own emergency exit.

### Elevated fallback

Double-click `FORCE STOP - MouseMux` on the desktop.

The fallback scheduled task:

1. Enumerates Windows processes.
2. Applies strict MouseMux process-name and executable-path checks.
3. Verifies the owner of port `41760` before adding it to the stop set.
4. Refuses to stop an unverified port owner.
5. Writes an audit log under `%ProgramData%\Troon\MultiMouseControl\logs`.

## Remove

Remove the support package and its Codex configuration:

```powershell
& "$env:LOCALAPPDATA\Troon\MultiMouseControl\scripts\Uninstall-MultiMouseControl.ps1" `
  -RemoveMcpConfiguration
```

This removes the scheduled task, shortcut, support files, and MouseMux MCP block. It does not uninstall the third-party MouseMux application.

## Development tests

The repository uses Pester `5.7.1` on a Windows GitHub runner:

```powershell
Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser
.\scripts\Invoke-Tests.ps1
```

Tests cover loopback URL validation, Codex TOML replacement and idempotence, strict process identity, required package files, manifest wiring, installer pinning, shortcut separation, and security documentation.
