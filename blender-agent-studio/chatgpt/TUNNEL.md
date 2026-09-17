# ChatGPT connection through Secure MCP Tunnel

This is the development/private ChatGPT transport for Blender Agent Studio.

The upstream MCP is a local stdio process. OpenAI Secure MCP Tunnel can launch and bridge that stdio process without changing the upstream MCP implementation.

## Prerequisites

- Blender 5.2 LTS, or a compatible Blender installation you intentionally choose.
- Bun 1.3.5 or newer.
- The pinned upstream checkout created by `../scripts/sync-upstream.ps1` or `bash ../scripts/sync-upstream.sh`.
- OpenAI `tunnel-client` from Tunnels management.
- A provisioned tunnel ID.
- A runtime API key with the tunnel permissions required for `doctor` and `run`.

Keep runtime and admin credentials separate. Do not commit either key to this repository.

## 1. Prepare Blender Agent Studio

From this integration directory on Windows:

```powershell
./scripts/sync-upstream.ps1
$env:BLENDER_EXECUTABLE = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
```

Verify that the MCP process can start:

```powershell
./scripts/run-mcp.ps1
```

On macOS/Linux:

```bash
bash ./scripts/sync-upstream.sh
export BLENDER_EXECUTABLE="/path/to/blender"
bash ./scripts/run-mcp.sh
```

Stop the manual MCP process before starting the tunnel. With a stdio binding, the tunnel client owns the MCP child process.

## 2. Create the tunnel profile

Create or retrieve the tunnel ID in OpenAI Tunnels management. Export the runtime key as `CONTROL_PLANE_API_KEY`.

PowerShell example:

```powershell
$runner = (Resolve-Path ".\scripts\run-mcp.ps1").Path
$mcpCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$runner`""

tunnel-client init `
  --sample sample_mcp_stdio_local `
  --profile blender-agent-studio `
  --tunnel-id tunnel_REPLACE_ME `
  --mcp-command $mcpCommand

tunnel-client doctor --profile blender-agent-studio --explain
tunnel-client run --profile blender-agent-studio
```

macOS/Linux example:

```bash
runner="$(pwd)/scripts/run-mcp.sh"

tunnel-client init \
  --sample sample_mcp_stdio_local \
  --profile blender-agent-studio \
  --tunnel-id tunnel_REPLACE_ME \
  --mcp-command "bash '$runner'"

tunnel-client doctor --profile blender-agent-studio --explain
tunnel-client run --profile blender-agent-studio
```

Only one active tunnel-client instance should use a given tunnel ID with a stdio binding.

## 3. Connect ChatGPT

While `tunnel-client run --profile blender-agent-studio` is healthy:

1. Open ChatGPT plugin/connector settings with developer mode enabled.
2. Create or add a plugin connection using the Secure MCP Tunnel connection type.
3. Select the Blender Agent Studio tunnel ID.
4. Confirm tool discovery includes the upstream `blender_*` tools.
5. Run the acceptance checks below.
6. Record the returned ChatGPT plugin ID, normally beginning with `plugin_asdk_app_`, in the repository integration metadata when available.

## 4. Acceptance checks

Run in this order:

1. `blender_version` returns the configured executable and exact Blender build.
2. `blender_inspect_asset` can inspect a known-safe test asset.
3. `blender_render_evidence` produces a contact sheet or requested views.
4. A write-capable Blender workflow produces output only in the approved output directory.
5. The same task remains usable from the upstream Codex plugin path.

Do not declare the ChatGPT app promoted until success and failure-path fixtures are recorded.

## Public distribution later

Secure MCP Tunnel is appropriate for private development and local/on-prem Blender access. A public ChatGPT plugin submission needs a stable HTTPS streamable-HTTP MCP endpoint, normally at `/mcp`.

For that phase, keep the tool schemas and authority boundary aligned with the upstream MCP. The remote adapter should not expose generic shell execution, generic Python execution, or unrestricted filesystem access. A safe public architecture is:

```text
ChatGPT
  -> HTTPS streamable-HTTP /mcp
  -> authenticated Blender job broker
  -> isolated Blender worker
  -> bounded artifacts + evidence
```

The local tunnel path and future public HTTP path are transports around the same Blender Agent Studio contract, not separate Blender implementations.
