#!/bin/bash

# Install WezTerm, set it up like the Terminator profile (configs/wezterm.lua)
# and make it the default terminal, so Ctrl+Alt+T opens it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/configs/wezterm.lua"

if command -v wezterm &>/dev/null; then
    echo "WezTerm is already installed."
else
    echo "Adding the WezTerm apt repository..."
    curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' \
        | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
    sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg

    echo "Installing WezTerm..."
    sudo apt-get update
    sudo apt-get install -y wezterm
fi

echo "Installing the config to ~/.wezterm.lua..."
if [ -f ~/.wezterm.lua ] && ! cmp -s "$CONFIG" ~/.wezterm.lua; then
    backup=~/.wezterm.lua.bak-$(date +%Y%m%d_%H%M%S)
    cp ~/.wezterm.lua "$backup"
    echo "Kept the old config as $backup"
fi
cp "$CONFIG" ~/.wezterm.lua

# GNOME launches the terminal through xdg-terminal-exec; these lists pick it.
echo "Making WezTerm the default terminal..."
echo "org.wezfurlong.wezterm.desktop" > ~/.config/xdg-terminals.list
for desktop in ${XDG_CURRENT_DESKTOP//:/ }; do
    list=~/.config/${desktop}-xdg-terminals.list
    if [ -f "$list" ]; then
        { echo "org.wezfurlong.wezterm.desktop"; grep -vx "org.wezfurlong.wezterm.desktop" "$list" || true; } > "$list.new"
        mv "$list.new" "$list"
    fi
done
# Older apps ask for x-terminal-emulator instead.
if [ -x /usr/bin/open-wezterm-here ]; then
    sudo update-alternatives --set x-terminal-emulator /usr/bin/open-wezterm-here || true
fi

echo "WezTerm installation complete. Ctrl+Alt+T opens it."
