# Blender Agent Studio integration

This directory adds a Troon-maintained portable integration for [ifBars/blender-agent-studio](https://github.com/ifBars/blender-agent-studio).

The upstream project remains authoritative for Blender workflows, specialist skills, the MCP implementation, tests, and Blender compatibility. This directory owns only the parallel ChatGPT/Codex packaging, routing, provenance pin, and connection workflow.

## Current upstream pin

- Repository: `ifBars/blender-agent-studio`
- Commit: `422dae578005e912caa745a723fc300931990164`
- Upstream plugin version: `0.6.2+codex.20260914085919`
- Tested upstream Blender target: Blender 5.2 LTS
- Upstream runtime: Bun 1.3.5+

See `upstream.json` for the machine-readable provenance record.

## Architecture

```text
                         Blender Agent Studio
                                  |
                    upstream implementation + skills
                                  |
                   Bun stdio MCP + Blender 5.2
                         /                 \
                        /                   \
              Codex plugin              ChatGPT app
          upstream native path       Secure MCP Tunnel
                                     during development
                                             |
                                   registered ChatGPT plugin
                                             |
                                  public HTTPS /mcp later
                                  if public distribution
```

The goal is one Blender implementation with two host surfaces, not two divergent Blender agents.

## Bootstrap the pinned upstream implementation

Windows PowerShell:

```powershell
./scripts/sync-upstream.ps1
```

macOS/Linux:

```bash
./scripts/sync-upstream.sh
```

The bootstrap scripts clone the upstream repository into the ignored `.upstream/` directory, detach it at the recorded commit, and install the upstream Bun dependencies.

## Codex

The canonical Codex installation remains upstream:

```bash
codex plugin marketplace add ifBars/blender-agent-studio
codex plugin add blender-agent-studio@blender-agent-studio
```

Do not replace the upstream Codex plugin with this adapter. This portable package exists so the same capability can be represented in the Troon plugin registry and connected to ChatGPT.

## ChatGPT development connection

ChatGPT cannot directly launch a local stdio MCP server from the cloud. Use OpenAI Secure MCP Tunnel to bridge ChatGPT to the upstream stdio server running beside Blender.

1. Run `scripts/sync-upstream.ps1` or `scripts/sync-upstream.sh`.
2. Set `BLENDER_EXECUTABLE` or put Blender on `PATH`.
3. Verify the MCP launches with `scripts/run-mcp.ps1` or `scripts/run-mcp.sh`.
4. Create an OpenAI Secure MCP Tunnel that invokes that same local MCP command.
5. In ChatGPT developer mode, create/connect a plugin using the tunnel.
6. Record the returned `plugin_asdk_app...` ID in this integration once assigned.

Detailed steps are in `chatgpt/TUNNEL.md`.

## Public ChatGPT distribution

Secure MCP Tunnel is for private development and local/on-prem access. A publicly distributable ChatGPT plugin needs a stable HTTPS streamable-HTTP MCP endpoint, conventionally `/mcp`.

The future public adapter should forward only the bounded Blender Agent Studio tools. It must not introduce a generic remote shell, arbitrary Python execution tool, or unrestricted filesystem surface.

## Safety boundary

Blender Agent Studio runs Blender and Blender Python locally. Review untrusted `.blend` files and scripts before enabling execution. Generated assets, renders, traces, and source material may contain private data.

## Ownership

- Upstream Blender implementation and specialist skills: Bars / `ifBars`
- Troon portable integration, ChatGPT connection, and registry metadata: `TroonCataroon`
- Upstream license: MIT
