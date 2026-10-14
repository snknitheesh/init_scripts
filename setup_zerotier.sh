#!/bin/bash

# Install ZeroTier and join a network.
#
#   ./setup_zerotier.sh                 # asks for the network ID (blank skips joining)
#   ./setup_zerotier.sh <network-id>    # the 16-character ID from ZeroTier Central
#
# After joining, authorize this machine in ZeroTier Central (my.zerotier.com):
# Networks -> your network -> Members -> tick "Auth" for the node ID printed below.

set -euo pipefail

NETWORK="${1:-}"

if command -v zerotier-cli &>/dev/null; then
    echo "ZeroTier is already installed ($(zerotier-cli -v))."
else
    echo "Installing ZeroTier..."
    curl -fsSL https://install.zerotier.com | sudo bash
fi
sudo systemctl enable --now zerotier-one

if [ -z "$NETWORK" ]; then
    read -rp "ZeroTier network ID to join (blank to skip): " NETWORK
fi

NODE=$(sudo zerotier-cli info | awk '{print $3}')
echo "This machine's node ID: $NODE"

if [ -n "$NETWORK" ]; then
    if ! [[ "$NETWORK" =~ ^[0-9a-fA-F]{16}$ ]]; then
        echo "A network ID is 16 hex characters, e.g. 8056c2e21c000001."
        exit 1
    fi
    sudo zerotier-cli join "$NETWORK"
    echo "Authorize node $NODE in ZeroTier Central, then wait for an address..."
    for _ in $(seq 1 60); do
        line=$(sudo zerotier-cli listnetworks | grep -i "$NETWORK" || true)
        if [[ "$line" == *" OK "* && "$line" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            echo "Joined."
            break
        fi
        sleep 5
    done
    sudo zerotier-cli listnetworks
fi

echo "ZeroTier setup complete."
