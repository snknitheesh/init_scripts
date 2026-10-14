#!/bin/bash

# Install Circle (Claude agents across machines) from git@github.com:snknitheesh/Circle.git.
# Clones or updates ~/circle, then runs Circle's own bootstrap, which installs
# the prerequisites (Rust, Claude Code, ZeroTier if asked), builds, starts the
# services and pairs the dashboard. Arguments go straight to the bootstrap:
#
#   ./setup_circle.sh                                         # asks what this machine is
#   ./setup_circle.sh --role laptop --hub <user>@<hub-ip>     # a laptop for an existing hub
#   ./setup_circle.sh --role agent                            # a device that runs sessions
#   ./setup_circle.sh --role all --bind <hub-ip>:7443         # hub + agent + dashboard
#
# <hub-ip> is the hub's ZeroTier address. With no arguments the bootstrap asks
# for everything it needs, so the examples are only shortcuts.
#
# Run it again with no arguments to update: it pulls and rebuilds whatever
# this machine already runs (hub, agent, dashboard).
#
# The repo is private: this machine's SSH key must be added to GitHub first.
# Laptops and devices reach the hub over ZeroTier: run ./setup_zerotier.sh first.

set -euo pipefail

REPO="git@github.com:snknitheesh/Circle.git"
DIR="${CIRCLE_DIR:-$HOME/circle}"

if ! command -v git &>/dev/null; then
    echo "Installing git..."
    sudo apt-get update
    sudo apt-get install -y git
fi

if ! git ls-remote "$REPO" HEAD &>/dev/null; then
    echo "Cannot read $REPO."
    echo "Add this machine's SSH key to GitHub (cat ~/.ssh/id_ed25519.pub), then run this again."
    exit 1
fi

if [ -d "$DIR/.git" ]; then
    echo "Updating Circle in $DIR..."
    git -C "$DIR" pull --ff-only
else
    echo "Cloning Circle into $DIR..."
    git clone "$REPO" "$DIR"
fi

# Already installed and nothing asked for: rebuild what this machine runs.
roles=()
[ -f ~/.config/circle/hub/hub.toml ] && roles+=(hub)
[ -f ~/.config/systemd/user/agentd-circle.service ] && roles+=(agent)
[ -x ~/.local/bin/zz ] && roles+=(laptop)
if [ $# -eq 0 ] && [ ${#roles[@]} -gt 0 ]; then
    echo "Circle is installed here as: ${roles[*]}. Rebuilding with the latest code..."
    if [[ " ${roles[*]} " == *" agent "* ]] && systemctl --user is-active --quiet agentd-circle; then
        read -rp "Updating the agent restarts it and stops running Claude sessions. Continue? [y/N]: " answer
        if ! [[ "$answer" =~ ^[Yy] ]]; then
            echo "Skipped the update. Run this again when the sessions are idle."
            exit 0
        fi
    fi
    for role in "${roles[@]}"; do
        "$DIR/scripts/install.sh" --role "$role"
    done
    echo "Circle is up to date."
    exit 0
fi

# The bootstrap reports what it installed and what to do next.
exec "$DIR/scripts/bootstrap.sh" "$@"
