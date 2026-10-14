#!/bin/bash

# =============================================================================
# setup_new_ubuntu.sh - Combined Ubuntu Setup Script
# =============================================================================
# One interactive installer for a new Ubuntu machine. Each installation
# prompts for yes/no and handles errors gracefully; anything already
# installed is checked for updates instead. The setup_*.sh scripts install single tools on their own.
# =============================================================================

set -o pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Logging ---
LOG_FILE="/tmp/setup_new_ubuntu_$(date +%Y%m%d_%H%M%S).log"

log_info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Ask user yes/no ---
ask_user() {
    local prompt="$1"
    local answer
    while true; do
        read -rp "$(echo -e "${CYAN}$prompt [y/n]: ${NC}")" answer
        case "$answer" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo])      return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

# --- Try/catch wrapper ---
# Runs a command block in a subshell. If it fails, logs the error and continues.
try_install() {
    local name="$1"
    shift
    log_info "Installing $name..."
    if ( set -e; "$@" ) >> "$LOG_FILE" 2>&1; then
        log_success "$name installed successfully."
    else
        log_error "$name installation failed. Check log: $LOG_FILE"
    fi
}

# --- Updates for what is already installed ---
# Runs an update command like try_install, without asking first.
try_update() {
    local name="$1"
    shift
    log_info "$name is installed. Checking for updates..."
    if ( set -e; "$@" ) >> "$LOG_FILE" 2>&1; then
        log_success "$name is up to date."
    else
        log_error "$name update failed. Check log: $LOG_FILE"
    fi
}

# Upgrades installed apt packages; main() refreshes the package lists once.
apt_update() {
    local name="$1"
    shift
    try_update "$name" sudo apt-get install --only-upgrade -y "$@"
}

# --- Separator ---
section() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
#  SECTION 1: IDE & Browsers
# =============================================================================

install_vscode() {
    if command -v code &>/dev/null; then
        if snap list code &>/dev/null; then
            try_update "VS Code" sudo snap refresh code
        else
            apt_update "VS Code" code
        fi
        return
    fi
    if ask_user "Install VS Code?"; then
        try_install "VS Code" bash -c "sudo snap install code --classic"
    fi
}

install_chrome() {
    if command -v google-chrome &>/dev/null || command -v google-chrome-stable &>/dev/null; then
        apt_update "Google Chrome" google-chrome-stable
        return
    fi
    if ask_user "Install Google Chrome?"; then
        try_install "Google Chrome" bash -c '
            wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb &&
            sudo apt install -y /tmp/google-chrome.deb &&
            rm -f /tmp/google-chrome.deb
        '
    fi
}

install_cursor() {
    if dpkg -s cursor &>/dev/null; then
        try_update "Cursor AI IDE" "$SCRIPT_DIR/setup_cursor.sh"
        return
    fi
    if ask_user "Install Cursor AI IDE?"; then
        try_install "Cursor AI IDE" "$SCRIPT_DIR/setup_cursor.sh"
    fi
}

# =============================================================================
#  SECTION 2: Terminal & Shell
# =============================================================================

install_terminator() {
    if command -v terminator &>/dev/null; then
        apt_update "Terminator" terminator
        return
    fi
    if ask_user "Install Terminator terminal emulator?"; then
        try_install "Terminator" bash -c "
            sudo apt-get install -y terminator &&
            mkdir -p ~/.config/terminator &&
            if [ -f '$SCRIPT_DIR/configs/config' ]; then
                cp '$SCRIPT_DIR/configs/config' ~/.config/terminator/config
            fi
        "
    fi
}

install_wezterm() {
    if command -v wezterm &>/dev/null && cmp -s "$SCRIPT_DIR/configs/wezterm.lua" ~/.wezterm.lua; then
        try_update "WezTerm" "$SCRIPT_DIR/setup_wezterm.sh"
        return
    fi
    if ask_user "Install WezTerm (Terminator keys, green on black) and make it the default terminal?"; then
        try_install "WezTerm" "$SCRIPT_DIR/setup_wezterm.sh"
    fi
}

# =============================================================================
#  SECTION 3: Git Setup
# =============================================================================

install_git() {
    if command -v git &>/dev/null; then
        apt_update "Git" git
    else
        if ask_user "Install Git?"; then
            try_install "Git" bash -c "sudo apt update && sudo apt install -y git"
        fi
    fi
}

setup_git_config() {
    local existing_name existing_email
    existing_name=$(git config --global user.name 2>/dev/null || true)
    existing_email=$(git config --global user.email 2>/dev/null || true)

    if [ -n "$existing_name" ] && [ -n "$existing_email" ]; then
        log_warn "Git already configured: $existing_name <$existing_email>. Skipping."
    else
        if ask_user "Configure Git user name/email?"; then
            read -rp "Enter Git user name: " git_name
            read -rp "Enter Git email: " git_email
            git config --global user.name "$git_name"
            git config --global user.email "$git_email"
            log_success "Git config set: $git_name <$git_email>"
        fi
    fi

    if [ -f ~/.ssh/id_ed25519 ]; then
        log_warn "SSH key already exists at ~/.ssh/id_ed25519. Skipping."
        echo "  $(cat ~/.ssh/id_ed25519.pub)"
    else
        if ask_user "Generate SSH key (ed25519)?"; then
            local email
            email=$(git config --global user.email 2>/dev/null || true)
            ssh-keygen -t ed25519 -C "${email:-$USER}"
            echo ""
            log_info "Your SSH public key:"
            cat ~/.ssh/id_ed25519.pub
            echo ""
            log_info "Add this key to GitHub: https://github.com/settings/ssh/new"
        fi
    fi
}

# =============================================================================
#  SECTION 4: APT Dev Tools
# =============================================================================

install_apt_dev_tools() {
    local tools=(curl python3-pip tmux byobu neovim git-lfs ripgrep nvtop htop net-tools)
    local missing=()

    for tool in "${tools[@]}"; do
        if ! dpkg -s "$tool" &>/dev/null; then
            missing+=("$tool")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        apt_update "APT dev tools" "${tools[@]}"
        return
    fi

    log_info "The following APT dev tools are not installed: ${missing[*]}"
    if ask_user "Install missing APT dev tools (${missing[*]})?"; then
        try_install "APT dev tools" bash -c "sudo apt update && sudo apt install -y ${missing[*]}"
    fi
}

# =============================================================================
#  SECTION 5: Snap Apps
# =============================================================================

install_snap_apps() {
    local apps=(slack spotify)
    for app in "${apps[@]}"; do
        if snap list "$app" &>/dev/null; then
            try_update "$app (snap)" sudo snap refresh "$app"
        else
            if ask_user "Install $app (snap)?"; then
                try_install "$app" bash -c "sudo snap install $app"
            fi
        fi
    done
}

# =============================================================================
#  SECTION 6: Pixi Package Manager
# =============================================================================

install_pixi() {
    if command -v pixi &>/dev/null; then
        try_update "Pixi" pixi self-update
        return
    fi
    if ask_user "Install Pixi package manager?"; then
        try_install "Pixi" bash -c "curl -fsSL https://pixi.sh/install.sh | bash"
    fi
}

install_pixi_tools() {
    local tools=(fzf fd-find ripgrep)
    if ! command -v pixi &>/dev/null; then
        log_warn "Pixi is not installed. Skipping pixi global tools."
        return
    fi
    if ask_user "Install pixi global tools (fzf, fd-find, ripgrep)?"; then
        for tool in "${tools[@]}"; do
            if pixi global list 2>/dev/null | grep -q "$tool"; then
                try_update "$tool (pixi)" pixi global update "$tool"
            else
                try_install "$tool (pixi)" bash -c "pixi global install $tool"
            fi
        done
    fi
}

# =============================================================================
#  SECTION 7: uv Python Installer
# =============================================================================

install_uv() {
    if command -v uv &>/dev/null; then
        try_update "uv" uv self update
        return
    fi
    if ask_user "Install uv (Python package installer)?"; then
        try_install "uv" bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi
}

# =============================================================================
#  SECTION 8: Rocker Tools
# =============================================================================

install_rocker_tools() {
    if ! command -v uv &>/dev/null; then
        log_warn "uv is not installed. Skipping rocker tools."
        return
    fi
    local tools=(rocker rockerc rockervsc)
    if ask_user "Install rocker tools (rocker, rockerc, rockervsc) via uv?"; then
        for tool in "${tools[@]}"; do
            if uv tool list 2>/dev/null | grep -q "$tool"; then
                try_update "$tool" uv tool upgrade "$tool"
            else
                try_install "$tool" bash -c "uv tool install $tool"
            fi
        done
    fi
}

# =============================================================================
#  SECTION 9: Rust & Cargo
# =============================================================================

install_rust() {
    if command -v rustc &>/dev/null; then
        try_update "Rust" rustup update
        return
    fi
    if ask_user "Install Rust and Cargo?"; then
        log_info "Running rustup installer (follow the interactive prompts)..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        if [ -f "$HOME/.cargo/env" ]; then
            source "$HOME/.cargo/env"
        fi
        log_success "Rust installed."
    fi
}

# =============================================================================
#  SECTION 10: lazydocker
# =============================================================================

install_lazydocker() {
    if command -v lazydocker &>/dev/null; then
        # Its installer replaces the binary with the latest release.
        try_update "lazydocker" bash -c "curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash"
        return
    fi
    if ask_user "Install lazydocker (Docker TUI)?"; then
        try_install "lazydocker" bash -c \
            "curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash"
    fi
}

# =============================================================================
#  SECTION 11: pre-commit
# =============================================================================

install_precommit() {
    if command -v pre-commit &>/dev/null; then
        apt_update "pre-commit" pre-commit
        return
    fi
    if ask_user "Install pre-commit?"; then
        try_install "pre-commit" bash -c "sudo apt-get install -y pre-commit"
    fi
}

# =============================================================================
#  SECTION 12: Earthly
# =============================================================================

install_earthly() {
    if command -v earthly &>/dev/null; then
        local latest
        latest=$(curl -fsSI https://github.com/earthly/earthly/releases/latest | awk 'tolower($1) == "location:" {print $2}' | tr -d '\r' | sed 's#.*/##')
        if earthly --version 2>/dev/null | grep -q " ${latest} "; then
            log_success "Earthly $latest is the latest version."
        else
            try_update "Earthly" sudo wget -q https://github.com/earthly/earthly/releases/latest/download/earthly-linux-amd64 -O /usr/local/bin/earthly
            sudo chmod +x /usr/local/bin/earthly
        fi
        return
    fi
    if ask_user "Install Earthly (build automation)?"; then
        try_install "Earthly" bash -c '
            sudo wget -q https://github.com/earthly/earthly/releases/latest/download/earthly-linux-amd64 -O /usr/local/bin/earthly &&
            sudo chmod +x /usr/local/bin/earthly &&
            if command -v docker &>/dev/null && docker info &>/dev/null; then
                /usr/local/bin/earthly bootstrap --with-autocomplete
            else
                echo "Docker not running - skipping earthly bootstrap (run \"earthly bootstrap --with-autocomplete\" after Docker is set up)"
            fi
        '
    fi
}

# =============================================================================
#  SECTION 13: Docker
# =============================================================================

install_docker() {
    if command -v docker &>/dev/null; then
        apt_update "Docker" docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        return
    fi
    if ask_user "Install Docker Engine?"; then
        try_install "Docker" bash -c '
            # Remove conflicting packages
            for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
                sudo apt-get remove -y "$pkg" 2>/dev/null || true
            done

            sudo apt update
            sudo apt install -y ca-certificates curl
            sudo install -m 0755 -d /etc/apt/keyrings
            sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            sudo chmod a+r /etc/apt/keyrings/docker.asc

            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
              $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
              sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt update

            sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

            sudo groupadd docker 2>/dev/null || true
            sudo usermod -aG docker $USER
        '
        log_info "You may need to log out and back in for Docker group changes to take effect."
    fi
}

# =============================================================================
#  SECTION 14: NVIDIA Container Toolkit
# =============================================================================

install_nvidia_docker() {
    if dpkg -s nvidia-container-toolkit &>/dev/null; then
        apt_update "NVIDIA Container Toolkit" nvidia-container-toolkit
        return
    fi
    if ask_user "Install NVIDIA Docker / Container Toolkit?"; then
        try_install "NVIDIA Container Toolkit" bash -c '
            curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
                sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>/dev/null
            curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
                sed "s#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g" | \
                sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
            sudo apt update
            sudo apt install -y nvidia-container-toolkit
            sudo nvidia-ctk runtime configure --runtime=docker
            sudo systemctl restart docker
        '
    fi
}

# =============================================================================
#  SECTION 15: Discord (from setup_discord.sh)
# =============================================================================

install_discord() {
    if command -v discord &>/dev/null || dpkg -s discord &>/dev/null; then
        try_update "Discord" "$SCRIPT_DIR/setup_discord.sh"
        return
    fi
    if ask_user "Install Discord?"; then
        try_install "Discord" bash -c '
            wget -q -O /tmp/discord.deb "https://discord.com/api/download?platform=linux&format=deb" &&
            sudo dpkg -i /tmp/discord.deb &&
            rm -f /tmp/discord.deb
        '
    fi
}

# =============================================================================
#  SECTION 16: File Manager Tools (from setup_filemanager.sh)
# =============================================================================

install_fsearch() {
    if command -v fsearch &>/dev/null; then
        apt_update "FSearch" fsearch
        return
    fi
    if ask_user "Install FSearch (fast file search)?"; then
        try_install "FSearch" bash -c "
            sudo add-apt-repository ppa:christian-boxdoerfer/fsearch-stable -y &&
            sudo apt update &&
            sudo apt install -y fsearch
        "
    fi
}

install_filelight() {
    if command -v filelight &>/dev/null; then
        apt_update "Filelight" filelight
        return
    fi
    if ask_user "Install Filelight (disk usage visualizer)?"; then
        try_install "Filelight" bash -c "sudo apt install -y filelight"
    fi
}

install_dolphin() {
    if command -v dolphin &>/dev/null; then
        apt_update "Dolphin & Konsole" dolphin konsole
        return
    fi
    if ask_user "Install Dolphin file manager & Konsole?"; then
        try_install "Dolphin & Konsole" bash -c "sudo apt install -y dolphin konsole"
    fi
}

# =============================================================================
#  SECTION 17: Increase Swap (from increase_swap.sh)
# =============================================================================

increase_swap() {
    local current_swap
    current_swap=$(swapon --show --noheadings --bytes 2>/dev/null | awk '{sum+=$3} END{print sum+0}')
    local current_gb=$((current_swap / 1073741824))

    log_info "Current swap size: ${current_gb}GB"
    if ask_user "Increase swap to 32GB?"; then
        read -rp "Enter swap size (e.g., 32G): " swap_size
        swap_size=${swap_size:-32G}
        try_install "Swap ($swap_size)" bash -c "
            sudo swapoff /swapfile 2>/dev/null || true
            sudo fallocate -l $swap_size /swapfile &&
            sudo chmod 600 /swapfile &&
            sudo mkswap /swapfile &&
            sudo swapon /swapfile &&
            { grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null; }
        "
        swapon --show
    fi
}

# =============================================================================
#  SECTION 18: Stress Test Tools
# =============================================================================

install_stress_tools() {
    if command -v stress-ng &>/dev/null; then
        apt_update "stress-ng" stress-ng
        return
    fi
    if ask_user "Install stress-ng (CPU/RAM stress testing)?"; then
        try_install "stress-ng" bash -c "sudo apt install -y stress-ng"
    fi
}

# =============================================================================
#  SECTION 19: Miniconda
# =============================================================================

install_miniconda() {
    if command -v conda &>/dev/null; then
        try_update "Conda" conda update -n base -y conda
        return
    fi
    if ask_user "Install Miniconda?"; then
        try_install "Miniconda" bash -c '
            curl -fsSL -o /tmp/Miniconda3-latest-Linux-x86_64.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh &&
            bash /tmp/Miniconda3-latest-Linux-x86_64.sh -b -p "$HOME/miniconda3" &&
            rm -f /tmp/Miniconda3-latest-Linux-x86_64.sh &&
            "$HOME/miniconda3/bin/conda" init bash
        '
    fi
}

# =============================================================================
#  SECTION 20: System Update
# =============================================================================

system_update() {
    if ask_user "Run full system update & upgrade?"; then
        try_install "System Update" bash -c "sudo apt-get update && sudo apt-get upgrade -y"
    fi
}

# =============================================================================
#  MAIN
# =============================================================================

install_zerotier() {
    if command -v zerotier-cli &>/dev/null; then
        apt_update "ZeroTier" zerotier-one
        return
    fi
    # Interactive (asks for the network ID), so it is not logged like the rest.
    if ask_user "Install ZeroTier and join a network?"; then
        "$SCRIPT_DIR/setup_zerotier.sh" || log_error "ZeroTier setup failed."
    fi
}

install_circle() {
    if command -v zz &>/dev/null; then
        log_info "Circle is installed. Checking for updates..."
        "$SCRIPT_DIR/setup_circle.sh" || log_error "Circle update failed."
        return
    fi
    # Interactive (it asks what this machine is), so it is not logged like the rest.
    if ask_user "Install Circle (Claude agents across machines)?"; then
        "$SCRIPT_DIR/setup_circle.sh" || log_error "Circle installation failed."
    fi
}

main() {
    echo ""
    echo -e "${GREEN}=========================================================${NC}"
    echo -e "${GREEN}       Ubuntu Setup Script - Interactive Installer        ${NC}"
    echo -e "${GREEN}=========================================================${NC}"
    echo ""
    log_info "Log file: $LOG_FILE"
    echo ""

    # Ensure sudo is available for the session
    sudo -v

    # Fresh package lists, so the update checks below see the newest versions.
    log_info "Refreshing package lists..."
    # shellcheck disable=SC2024  # the log is ours; only apt needs root
    sudo apt-get update >> "$LOG_FILE" 2>&1 || log_warn "apt-get update failed; update checks may be stale."

    section "IDE & Browsers"
    install_vscode
    install_chrome
    install_cursor

    section "Terminal & Shell"
    install_terminator
    install_wezterm

    section "Git"
    install_git
    setup_git_config

    section "APT Dev Tools"
    install_apt_dev_tools

    section "Snap Apps"
    install_snap_apps

    section "Pixi Package Manager"
    install_pixi
    install_pixi_tools

    section "uv (Python Installer)"
    install_uv

    section "Rocker Tools"
    install_rocker_tools

    section "Rust & Cargo"
    install_rust

    section "lazydocker"
    install_lazydocker

    section "pre-commit"
    install_precommit

    section "Earthly"
    install_earthly

    section "Docker Engine"
    install_docker

    section "NVIDIA Container Toolkit"
    install_nvidia_docker

    section "Discord"
    install_discord

    section "File Manager Tools"
    install_fsearch
    install_filelight
    install_dolphin

    section "Swap Configuration"
    increase_swap

    section "Stress Test Tools"
    install_stress_tools

    section "Miniconda"
    install_miniconda

    section "ZeroTier"
    install_zerotier

    section "Circle"
    install_circle

    section "System Update"
    system_update

    echo ""
    echo -e "${GREEN}=========================================================${NC}"
    echo -e "${GREEN}  Setup complete! Log file: $LOG_FILE${NC}"
    echo -e "${GREEN}  You may need to restart your machine for all changes.${NC}"
    echo -e "${GREEN}=========================================================${NC}"
}

main "$@"
