#!/usr/bin/env bash
# takes the plugin out. the layout and the home assistant token stay in ~/.config/omarchy-widgets
set -euo pipefail

ID=eduardo.widgets
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

omarchy plugin disable "$ID" >/dev/null 2>&1 || true
[[ -L $HOME/.config/omarchy/plugins/$ID ]] && rm "$HOME/.config/omarchy/plugins/$ID"
rm -f "$APPS/widgets.desktop" "$APPS/widgets-edit.desktop"
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
echo "widgets removed"
