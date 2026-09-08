#!/usr/bin/env bash
# Install Godot official Android Gradle build template into this game
# (Editor: Project → Install Android Build Template…)
# Uses already-downloaded export templates — no network required.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER="${1:-4.6.2.stable.mono}"
SRC="${HOME}/Library/Application Support/Godot/export_templates/${VER}/android_source.zip"
DEST="${ROOT}/android/build"

if [[ ! -f "$SRC" ]]; then
  echo "Missing: $SRC" >&2
  echo "In Godot: Editor → Manage Export Templates → download ${VER}" >&2
  echo "Or place android_source.zip there manually." >&2
  exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"
unzip -q "$SRC" -d "$DEST"
echo "$VER" > "$DEST/.build_version"
# Prevent Godot from importing Gradle tree as resources
: > "$DEST/.gdignore"
mkdir -p "${ROOT}/android"
printf '*\n!.gdignore\n' > "${ROOT}/android/.gdignore"

echo "Installed Android build template → ${DEST}"
echo "version: $(cat "$DEST/.build_version")"
echo "Next: Export → Android → enable \"Gradle Build\" / use installed template."
