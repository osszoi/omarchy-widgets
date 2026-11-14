#!/usr/bin/env bash
# links the plugin into the omarchy shell and adds two launcher entries: Widgets (peek) and Edit Widgets
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
ID=eduardo.widgets
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

mkdir -p "$HOME/.config/omarchy/plugins" "$APPS"
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

entry() {
  cat >"$APPS/$1.desktop" <<ENTRY
[Desktop Entry]
Version=1.0
Type=Application
Name=$2
Comment=$3
Exec=omarchy-shell widgets $4
Icon=preferences-desktop-display
Terminal=false
Categories=Utility;
Keywords=widgets;desktop;
ENTRY
}
entry widgets "Widgets" "Bring the desktop widgets above the windows" peek
entry widgets-edit "Edit Widgets" "Move, resize, add or remove desktop widgets" edit

echo "widgets installed. hold a tile to rearrange, or run: omarchy-shell widgets edit"
