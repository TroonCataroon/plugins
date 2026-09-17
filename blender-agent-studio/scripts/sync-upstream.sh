#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION="${1:-$ROOT/.upstream/blender-agent-studio}"
REPOSITORY="https://github.com/ifBars/blender-agent-studio.git"
COMMIT="422dae578005e912caa745a723fc300931990164"
PLUGIN_DIR="$DESTINATION/plugins/blender-agent-studio"

command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 1; }
command -v bun >/dev/null 2>&1 || { echo "Bun 1.3.5 or newer is required" >&2; exit 1; }

if [[ ! -d "$DESTINATION/.git" ]]; then
  mkdir -p "$(dirname "$DESTINATION")"
  git clone "$REPOSITORY" "$DESTINATION"
else
  git -C "$DESTINATION" remote set-url origin "$REPOSITORY"
fi

git -C "$DESTINATION" fetch origin main --tags
git -C "$DESTINATION" fetch origin "$COMMIT"
git -C "$DESTINATION" checkout --detach "$COMMIT"

bun install --cwd "$PLUGIN_DIR"

echo "Pinned Blender Agent Studio ready at $DESTINATION"
echo "Commit: $COMMIT"
echo "Next: set BLENDER_EXECUTABLE if Blender is not already on PATH."
