#!/bin/bash

# Install WezTerm, set it up like the Terminator profile (configs/wezterm.lua)
# and make it the default terminal, so Ctrl+Alt+T opens it. Run it again to
# update WezTerm and re-apply the config.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/configs/wezterm.lua"

if [ ! -f /etc/apt/sources.list.d/wezterm.list ]; then
    echo "Adding the WezTerm apt repository..."
    curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' \
        | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
    sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
fi

# The nightly build: the last stable release (20240203) crashes on GNOME
# Wayland with current NVIDIA drivers. The two packages conflict, so drop the
# stable one first.
if dpkg -s wezterm &>/dev/null; then
    echo "Removing the stable WezTerm release..."
    sudo apt-get remove -y wezterm
fi

echo "Installing or updating WezTerm nightly..."
sudo apt-get update
sudo apt-get install -y wezterm-nightly

echo "Installing the config to ~/.wezterm.lua..."
if [ -f ~/.wezterm.lua ] && ! cmp -s "$CONFIG" ~/.wezterm.lua; then
    backup=~/.wezterm.lua.bak-$(date +%Y%m%d_%H%M%S)
    cp ~/.wezterm.lua "$backup"
    echo "Kept the old config as $backup"
fi
cp "$CONFIG" ~/.wezterm.lua

# GNOME launches the terminal through xdg-terminal-exec; these lists pick it.
echo "Making WezTerm the default terminal..."
mkdir -p ~/.config
echo "org.wezfurlong.wezterm.desktop" > ~/.config/xdg-terminals.list
# Outside a desktop session (SSH, a console) there is no XDG_CURRENT_DESKTOP;
# Ubuntu's desktop is the one to set up then.
desktops="${XDG_CURRENT_DESKTOP:-ubuntu:GNOME}"
for desktop in ${desktops//:/ }; do
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
