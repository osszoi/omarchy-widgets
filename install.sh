#!/usr/bin/env bash
# links the plugin into the omarchy shell. binding a key and the blur rule are in the README
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
ID=eduardo.widgets

mkdir -p "$HOME/.config/omarchy/plugins"
ln -sfn "$ROOT" "$HOME/.config/omarchy/plugins/$ID"

# the shell takes a moment to notice a new plugin folder, enabling it before that fails
enabled=false
for _ in 1 2 3 4 5 6 7 8; do
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  if omarchy plugin enable "$ID" >/dev/null 2>&1; then
    enabled=true
    break
  fi
  sleep 1
done
if [[ $enabled != true ]]; then
  echo "could not enable $ID, is omarchy-shell running?" >&2
  exit 1
fi

echo "widgets installed. lift them with: omarchy-shell widgets peek"
