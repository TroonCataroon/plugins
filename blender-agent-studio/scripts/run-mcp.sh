#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="${1:-$ROOT/.upstream/blender-agent-studio}"
SERVER="$UPSTREAM/plugins/blender-agent-studio/mcp/server.ts"

command -v bun >/dev/null 2>&1 || { echo "Bun is required. Run sync-upstream.sh after installing Bun 1.3.5+." >&2; exit 1; }

if [[ ! -f "$SERVER" ]]; then
  echo "Pinned upstream checkout is missing. Run scripts/sync-upstream.sh first." >&2
  exit 1
fi

if [[ -z "${BLENDER_EXECUTABLE:-}" ]] && ! command -v blender >/dev/null 2>&1; then
  echo "Warning: Blender is not on PATH and BLENDER_EXECUTABLE is not set. Blender-backed tools will fail until configured." >&2
fi

exec bun "$SERVER"
