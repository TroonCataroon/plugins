---
name: blender-agent-studio
description: Route Blender modeling, scene, animation, rendering, inspection, and repair work through the registered Blender Agent Studio MCP or the pinned upstream Codex plugin. Use for requests that need Blender execution or Blender-specific evidence rather than generic 3D advice.
---

# Blender Agent Studio adapter

## Authority

The Blender workflows, specialist behavior, MCP tool implementation, Blender compatibility, and validation logic are owned by the pinned upstream `ifBars/blender-agent-studio` revision recorded in `../../upstream.json`.

Do not copy or silently rewrite upstream specialist instructions into this adapter. Keep Troon-specific host integration here and contribute Blender-domain improvements upstream when appropriate.

## Route the request

1. Prefer the registered Blender Agent Studio MCP tools when the ChatGPT app is connected.
2. In Codex, prefer the installed upstream Blender Agent Studio plugin and its specialist skills.
3. Verify Blender availability with `blender_version` before expensive work when runtime state is unknown.
4. For existing assets, inspect first, then render evidence, then repair the highest-impact issue.
5. Preserve reproducibility. Keep the `.blend` plus generated or maintained Python source when the workflow creates or changes geometry procedurally.
6. Use authored-scene rendering for final/cinematic scene review and standardized evidence rendering for geometry validation.
7. Validate exports when the requested deliverable targets a game engine or interchange format.

## Safety and execution boundary

- Treat Blender scripts and untrusted `.blend` files as executable content.
- Do not add a generic arbitrary-Python, arbitrary-shell, or unrestricted-filesystem MCP tool.
- Keep outputs in explicit new or approved directories.
- Do not claim an asset passed validation unless the relevant MCP/tool evidence completed successfully.

## ChatGPT transport

For private development, connect ChatGPT to the upstream stdio MCP through OpenAI Secure MCP Tunnel. For public distribution, use a stable HTTPS streamable-HTTP MCP endpoint. The transport adapter must preserve the upstream tool schemas and bounded authority.

## Completion evidence

A completed Blender task should report the deliverable paths plus the validation evidence that actually ran, such as Blender version, asset inspection, render evidence, export verification, or relevant benchmark result.
