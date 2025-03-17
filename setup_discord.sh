#!/bin/bash

# Script to download and install the latest Discord

echo "Downloading the latest Discord .deb package..."
wget -O discord.deb "https://discord.com/api/download?platform=linux&format=deb"

echo "Installing Discord..."
sudo dpkg -i discord.deb

echo "Cleaning up downloaded files..."
rm discord.deb

echo "Discord installation completed!"