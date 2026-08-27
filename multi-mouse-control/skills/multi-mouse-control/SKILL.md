---
name: multi-mouse-control
description: Install, configure, verify, troubleshoot, or remove the Windows MouseMux Input Mapper MCP setup for independent physical and virtual cursors. Use when the user wants simultaneous human and AI input without sharing one foreground pointer.
---

# Multi Mouse Control

## Purpose

Set up a Windows workstation so the physical user retains an independent mouse and keyboard while a virtual MouseMux user is constrained to a selected window and exposed through Input Mapper MCP.

## Required safety model

1. Accept only the local Input Mapper endpoint on `127.0.0.1`, `localhost`, or `::1`, port `41760`.
2. Keep **Arm MCP** off until the virtual cursor is visibly locked to a disposable test window.
3. Use `default_tools_approval_mode = "prompt"` during initial setup.
4. Never treat MouseMux window locking as a Windows security sandbox.
5. Never interact with credentials, administrator prompts, financial applications, production systems, or another user's window during acceptance testing.
6. Use MouseMux's built-in `Ctrl+Alt+F12` exit first. Use `FORCE STOP - MouseMux` only as the separate current-user fallback.
7. Never stop an unknown process merely because it owns port `41760`.
8. Never create an elevated scheduled task that executes the support scripts from user-writable storage.

## Workflow

1. Read `README.md`, `docs/SECURITY.md`, and `docs/ACCEPTANCE-TEST.md`.
2. Run `scripts/Discover-InputDevices.ps1` and preserve the device inventory.
3. Run `scripts/Install-MultiMouseControl.ps1` from an extracted, trusted copy of this package.
4. Have the user complete the MouseMux UI assignments described in `docs/MOUSEMUX-UI-SETUP.md`.
5. Run `scripts/Start-AgentSandbox.ps1` and lock the virtual seat to the generated Notepad window.
6. In Input Mapper, enable MCP but leave **Arm MCP** off.
7. Copy the exact endpoint displayed by Input Mapper and run `scripts/Configure-MouseMuxMcp.ps1 -Url <endpoint>`.
8. Restart Codex or ChatGPT desktop, then inspect the MCP server and tools.
9. Run `scripts/Verify-MultiMouseControl.ps1`.
10. Complete every manual gate in `docs/ACCEPTANCE-TEST.md` before using live actuation.

## Tool allowlisting

Do not guess Input Mapper tool names. First inspect the tools exposed by the installed version. Then rerun `Configure-MouseMuxMcp.ps1` with `-EnabledTool` values that are required for the approved workflow. Keep shell, process, file operation, power, and unrestricted program-launch tools disabled unless the user explicitly approves a sandboxed use case.

Tool names must pass the configuration writer's identifier validation. Do not bypass it to insert raw TOML.

## Troubleshooting order

1. Confirm MouseMux is running.
2. Confirm Input Mapper MCP is enabled on loopback port `41760`.
3. Confirm **Arm MCP** is intentionally on or off for the current test step.
4. Confirm the virtual user is locked to the expected window.
5. Confirm `~/.codex/config.toml` contains one `[mcp_servers.mousemux]` table.
6. Confirm the retired elevated scheduled task is absent.
7. Run `Verify-MultiMouseControl.ps1` and inspect the JSON report.
8. If the port owner is unverified, disarm MCP and investigate it. Do not terminate it automatically.

## Removal

Use `scripts/Uninstall-MultiMouseControl.ps1 -RemoveMcpConfiguration` to remove the support package and Codex MCP block. This intentionally does not uninstall the third-party MouseMux application.
