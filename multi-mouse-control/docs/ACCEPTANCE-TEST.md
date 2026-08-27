# Multi Mouse Control Acceptance Test

Do not use the setup for normal work until every required item passes.

## Preflight

- [ ] MouseMux V3 is installed from the signed official installer.
- [ ] `Discover-InputDevices.ps1` records the expected physical mice and keyboards.
- [ ] Troon's primary mouse and keyboard are assigned to the cyan Troon seat.
- [ ] The magenta Agent virtual seat has no physical devices assigned.
- [ ] Input Mapper MCP uses `127.0.0.1`, `localhost`, or `::1` on port `41760`.
- [ ] Input Mapper **Arm MCP** is off.
- [ ] The Codex MouseMux server uses prompt approval.
- [ ] `Verify-MultiMouseControl.ps1` has no unexplained critical failure.

## Disposable sandbox

- [ ] Run `Start-AgentSandbox.ps1`.
- [ ] Confirm the generated Notepad document contains the boundary instructions.
- [ ] Lock the Agent virtual seat to that Notepad window.
- [ ] Confirm the magenta cursor cannot leave the Notepad window.
- [ ] Confirm the cyan physical cursor can move normally outside the Notepad window.

## Independent input

- [ ] Arm MCP manually.
- [ ] Approve only the minimum movement, click, or typing call required for the test.
- [ ] Have the Agent type exactly `MOUSEMUX ACCEPTANCE TEST PASSED` in the sandbox document.
- [ ] Move and click with the physical mouse while the Agent is typing.
- [ ] Confirm physical input does not redirect or interrupt the Agent cursor.
- [ ] Confirm Agent input does not move the physical cursor.
- [ ] Confirm no text or click reaches another application.
- [ ] Disarm MCP immediately after the test.

## Emergency exit

- [ ] Re-arm MCP in the disposable sandbox.
- [ ] Press `Ctrl+Alt+F12`.
- [ ] Confirm MouseMux exits or disables multiplexed input.
- [ ] Confirm the physical mouse and keyboard retain control.
- [ ] Restart MouseMux and restore the sandbox lock.
- [ ] Re-arm MCP.
- [ ] Double-click `FORCE STOP - MouseMux`.
- [ ] Confirm verified MouseMux processes stop.
- [ ] Confirm an unrelated application remains running.
- [ ] Review the force-stop log for the expected process IDs.

## Negative boundaries

- [ ] Attempt to configure an MCP URL using a LAN address and confirm the script rejects it.
- [ ] Attempt to configure port `41761` and confirm the script rejects it.
- [ ] Attempt to configure a URL with credentials, a query, or a fragment and confirm the script rejects it.
- [ ] Confirm ChatGPT web is not assumed to read the local Codex configuration.
- [ ] Confirm no administrator prompt, credential dialog, financial application, or production system was used during testing.

## Final decision

- [ ] All required checks passed.
- [ ] The allowed Input Mapper tools have been reviewed.
- [ ] An explicit tool allowlist is configured when practical.
- [ ] The user understands that window locking is not a Windows security boundary.
- [ ] Sensitive workflows will run in a dedicated standard-user session or VM.
