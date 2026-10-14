#!/bin/bash

# Install Cursor from its official .deb, which brings the app menu entry and
# icon with it. Downloads the latest stable release for this machine (x86_64
# or arm64); nothing needs to be fetched by hand. Run it again to update.

set -euo pipefail

case "$(dpkg --print-architecture)" in
    amd64) platform=linux-x64 ;;
    arm64) platform=linux-arm64 ;;
    *) echo "Cursor has no Linux build for $(dpkg --print-architecture)."; exit 1 ;;
esac

echo "Finding the latest Cursor release..."
release=$(curl -fsSL "https://www.cursor.com/api/download?platform=$platform&releaseTrack=stable")
latest=$(python3 -c 'import json, sys; print(json.load(sys.stdin)["version"])' <<<"$release")
url=$(python3 -c 'import json, sys; print(json.load(sys.stdin)["debUrl"])' <<<"$release")

# The package version carries a build suffix: 3.24.18-1791916893.
installed=$(dpkg-query -W -f='${Version}' cursor 2>/dev/null | cut -d- -f1 || true)
if [ "$installed" = "$latest" ]; then
    echo "Cursor $installed is the latest version."
    exit 0
fi
if [ -n "$installed" ]; then
    echo "Updating Cursor $installed -> $latest..."
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# apt reads local .debs as an unprivileged user, so the folder must be readable.
chmod 755 "$tmp"

echo "Downloading $(basename "$url")..."
curl -fL --progress-bar -o "$tmp/cursor.deb" "$url"
chmod 644 "$tmp/cursor.deb"

# The old AppImage installer could leave a menu entry pointing at nothing.
if grep -qs '/opt/cursor.appimage' /usr/share/applications/cursor.desktop; then
    echo "Removing the old AppImage menu entry..."
    sudo rm -f /usr/share/applications/cursor.desktop /opt/cursor.appimage /opt/cursor.png
fi

echo "Installing Cursor..."
sudo apt-get install -y "$tmp/cursor.deb"

echo "Cursor installation complete. You can find it in your application menu."
