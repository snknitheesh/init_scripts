#!/bin/bash
set -e

# Disable the swap file (it may not exist yet)
echo "Disabling the swap file..."
sudo swapoff /swapfile 2>/dev/null || true

# Create a 32GB swap file
echo "Allocating 32GB for the swap file..."
sudo fallocate -l 32G /swapfile

# Only root may read it, or mkswap refuses to trust it
sudo chmod 600 /swapfile

# Mark the file as a swap file
echo "Marking the file as a swap file..."
sudo mkswap /swapfile

# Enable the swap file
echo "Enabling the swap file..."
sudo swapon /swapfile

# Keep it after a reboot
if ! grep -q '^/swapfile ' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

# Display the current swap file usage and size
echo "Current swap file status:"
swapon --show