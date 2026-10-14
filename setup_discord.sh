#!/bin/bash

# Install the latest Discord, or update it when a newer version is out.

set -euo pipefail

# The download link redirects to the versioned .deb: .../discord-1.0.162.deb
url=$(curl -fsSI "https://discord.com/api/download?platform=linux&format=deb" \
    | awk 'tolower($1) == "location:" {print $2}' | tr -d '\r')
latest=$(basename "$url" .deb | sed 's/^discord-//')
installed=$(dpkg-query -W -f='${Version}' discord 2>/dev/null || true)

if [ "$installed" = "$latest" ]; then
    echo "Discord $installed is the latest version."
    exit 0
fi
if [ -n "$installed" ]; then
    echo "Updating Discord $installed -> $latest..."
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# apt reads local .debs as an unprivileged user, so the folder must be readable.
chmod 755 "$tmp"

echo "Downloading Discord $latest..."
curl -fL --progress-bar -o "$tmp/discord.deb" "$url"
chmod 644 "$tmp/discord.deb"

echo "Installing Discord..."
sudo apt-get install -y "$tmp/discord.deb"

echo "Discord installation completed!"
