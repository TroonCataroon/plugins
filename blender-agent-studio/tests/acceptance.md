# Blender Agent Studio integration acceptance fixtures

Status legend: `UNRUN`, `PASS`, `FAIL`, `BLOCKED`.

The adapter is not promoted until representative success and failure fixtures have evidence from the actual target runtime.

| ID | Surface | Fixture | Expected evidence | Status |
|---|---|---|---|---|
| BAS-01 | ChatGPT | Discover tools through Secure MCP Tunnel | `blender_*` tool inventory resolves without schema errors | UNRUN |
| BAS-02 | ChatGPT | Call `blender_version` | Exact executable, exit code 0, Blender build fingerprint | UNRUN |
| BAS-03 | ChatGPT | Inspect a known-safe `.blend` or GLB fixture | Machine-readable geometry/material/animation metrics written to approved output | UNRUN |
| BAS-04 | ChatGPT | Render standardized evidence for the safe fixture | Requested views plus evidence manifest/contact sheet | UNRUN |
| BAS-05 | ChatGPT | Supply a missing asset path | Bounded tool error, no unrelated filesystem mutation, useful recovery message | UNRUN |
| BAS-06 | ChatGPT | Supply Blender-unavailable runtime | Explicit runtime failure, no false success claim | UNRUN |
| BAS-07 | Codex | Run equivalent inspect/render task through upstream plugin | Upstream plugin completes with equivalent bounded artifacts | UNRUN |
| BAS-08 | Cross-surface | Compare tool names/schemas for shared MCP functions | No adapter-induced schema drift | UNRUN |
| BAS-09 | Security | Attempt to request arbitrary shell/Python through MCP | No generic arbitrary execution tool is exposed | UNRUN |
| BAS-10 | Regression | Re-run BAS-02 through BAS-04 after upstream update | Prior passing fixtures remain passing or regression is documented before repin | UNRUN |

## Promotion gate

Minimum integration promotion requires:

- BAS-01 through BAS-09 passing on the target Blender machine.
- Recorded Blender, Bun, tunnel-client, upstream commit, and adapter version.
- Any upstream repin reruns BAS-02 through BAS-10.
- No public distribution claim until the remote HTTPS MCP path has its own authentication, isolation, artifact-retention, and failure-path evaluation.
