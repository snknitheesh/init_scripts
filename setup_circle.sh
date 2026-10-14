#!/bin/bash

# Install Circle (Claude agents across machines) from git@github.com:snknitheesh/Circle.git.
# Clones or updates ~/circle, then runs Circle's own bootstrap, which installs
# the prerequisites (Rust, Claude Code, ZeroTier if asked), builds, starts the
# services and pairs the dashboard. Arguments go straight to the bootstrap:
#
#   ./setup_circle.sh                                         # asks what this machine is
#   ./setup_circle.sh --role laptop --hub zozo@10.160.17.97   # a laptop for the existing hub
#   ./setup_circle.sh --role agent                            # a device that runs sessions
#   ./setup_circle.sh --role all --bind 10.160.17.97:7443     # hub + agent + dashboard
#
# The repo is private: this machine's SSH key must be added to GitHub first.

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

# The bootstrap reports what it installed and what to do next.
exec "$DIR/scripts/bootstrap.sh" "$@"
