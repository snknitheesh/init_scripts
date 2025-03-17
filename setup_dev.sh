#!/bin/bash

# Install vscode
sudo snap install code --classic

# Install chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install ./google-chrome-stable_current_amd64.deb -y
sudo rm -rf google-chrome-stable_current_amd64.deb

# Install terminator
sudo apt-get install terminator -y
source ~/.bashrc
sudo rm -rf ~/.config/terminator/config
cp ./configs/config ~/.config/terminator/config

# Install git and setup configs
sudo apt update
sudo apt install git -y
git --version
git config --global user.name snknitheesh # Change if you need it
git config --global user.email snknitheesh@gmail.com # Change if you need it
ssh-keygen -t ed25519 -C snknitheesh@gmail.com
xdg-open "https://github.com/settings/ssh/new"

# Install additional debs 
sudo apt install -y curl python3-pip tmux byobu neovim git-lfs ripgrep pinta nvtop htop net-tools 
snap install slack spotify

# Install pixi
curl -fsSL https://pixi.sh/install.sh | bash

# Install basic dev tools
pixi global install fzf fd-find ripgrep

# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env

# Set up rocker development environment tool
uv tool install rocker 
uv tool install rockerc 
uv tool install rockervsc 

# Install Rust and Cargo
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"

# lazydocker
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

source ~/.bashrc
sudo apt-get install pre-commit -y
sudo /bin/sh -c 'wget https://github.com/earthly/earthly/releases/latest/download/earthly-linux-amd64 -O /usr/local/bin/earthly && chmod +x /usr/local/bin/earthly && /usr/local/bin/earthly bootstrap --with-autocomplete'

echo "ssh-ID"
cat ~/.ssh/id_ed25519.pub
echo "Installed all developer settings. Please run setup_host.sh to install docker and nvidia"