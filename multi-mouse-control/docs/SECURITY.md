# Security Model

## Boundary statement

MouseMux window locking is not a Windows security boundary. It controls input routing. It does not create a protected desktop, process sandbox, credential boundary, filesystem boundary, network boundary, or privilege boundary.

A local MCP endpoint is also not automatically safe. Input Mapper can expose nodes capable of launching programs, running shell commands, operating on files, terminating processes, and changing power state. Treat the available tool set as code execution capability.

## Trust assumptions

This package assumes:

- The Windows host and current user account are trusted.
- The official MouseMux installer is downloaded over HTTPS from `files.mousemux.com`.
- Windows validates the installer's Authenticode signature before launch.
- Input Mapper listens only on loopback port `41760`.
- The human user controls when **Arm MCP** is enabled.
- Codex or ChatGPT desktop asks for approval before each MouseMux tool call during initial setup.

If any assumption is false, stop the setup and investigate before enabling live actuation.

## Threat model

### Unintended foreground input

A virtual cursor could be assigned to the wrong window or lose its intended lock. The first test must use a disposable Notepad document with no sensitive data. Keep every other sensitive application closed.

### Excessive tool exposure

Input Mapper may expose more tools than the immediate workflow requires. Start with prompt approval. Inspect the actual server tool inventory. Add an `enabled_tools` allowlist only after the names and behavior are verified.

Do not allow shell, process, file operation, power, or unrestricted program-launch tools merely to avoid prompts.

### Port-owner confusion

Another process can listen on port `41760`. The force-stop script therefore does not trust the port number alone. It stops the listener only when the process also passes strict MouseMux identity checks. Unknown listeners are logged and left running.

### Privilege crossing

Do not permit the virtual seat to interact with:

- User Account Control prompts
- Password or passkey dialogs
- Browser password managers
- Banking, trading, or payment applications
- Windows security settings
- Production HMA systems or sensitive client data
- Remote administration consoles

For sensitive work, use a dedicated standard Windows account or a dedicated virtual machine. Lock the virtual seat to that session or VM window.

### Installer substitution

The installer URL is pinned to MouseMux V3 `3.0.19` on the official file host. The script rejects alternate hosts, paths, queries, and fragments, then requires a valid Authenticode signature. Updating the version requires a code change, test update, review, and a fresh signature check.

## Emergency response

1. Press `Ctrl+Alt+F12` to invoke MouseMux's built-in exit.
2. If MouseMux remains active, double-click `FORCE STOP - MouseMux`.
3. Confirm Input Mapper **Arm MCP** is off.
4. Disconnect or close the affected MCP client.
5. Review `%ProgramData%\Troon\MultiMouseControl\logs\force-stop.log`.
6. Run `Verify-MultiMouseControl.ps1`.
7. Investigate any unverified listener on port `41760` before restarting.

## Residual risks

- The process-name allowlist can become stale when MouseMux changes executable names.
- An attacker with local code execution can impersonate a process name.
- Authenticode validates publisher identity and file integrity, not application behavior.
- Window locking cannot prevent an approved application from exposing sensitive content inside the locked window.
- Manual UI state, including **Arm MCP**, cannot be fully verified by the provided scripts.

Do not treat a passing automated report as authorization to use the system on sensitive data. The manual acceptance test remains mandatory.
