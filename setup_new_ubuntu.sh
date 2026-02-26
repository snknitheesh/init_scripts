#!/bin/bash

# =============================================================================
# setup_new_ubuntu.sh - Combined Ubuntu Setup Script
# =============================================================================
# Combines all individual setup scripts into one interactive installer.
# Each installation prompts for yes/no, checks if already installed,
# and handles errors gracefully.
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

# --- Separator ---
section() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
#  SECTION 1: IDE & Browsers (from setup_dev.sh)
# =============================================================================

install_vscode() {
    if command -v code &>/dev/null; then
        log_warn "VS Code is already installed. Skipping."
        return
    fi
    if ask_user "Install VS Code?"; then
        try_install "VS Code" bash -c "sudo snap install code --classic"
    fi
}

install_chrome() {
    if command -v google-chrome &>/dev/null || command -v google-chrome-stable &>/dev/null; then
        log_warn "Google Chrome is already installed. Skipping."
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
    if [ -f /opt/cursor.appimage ]; then
        log_warn "Cursor AI IDE is already installed. Skipping."
        return
    fi
    if ask_user "Install Cursor AI IDE? (requires Cursor.AppImage and icon.png in $SCRIPT_DIR)"; then
        if [ ! -f "$SCRIPT_DIR/Cursor.AppImage" ]; then
            log_error "Cursor.AppImage not found in $SCRIPT_DIR. Skipping."
            return
        fi
        try_install "Cursor AI IDE" bash -c "
            sudo cp '$SCRIPT_DIR/Cursor.AppImage' /opt/cursor.appimage &&
            sudo chmod +x /opt/cursor.appimage &&
            if [ -f '$SCRIPT_DIR/icon.png' ]; then
                sudo cp '$SCRIPT_DIR/icon.png' /opt/cursor.png
            fi &&
            sudo bash -c 'cat > /usr/share/applications/cursor.desktop' <<'DESKTOP'
[Desktop Entry]
Name=Cursor AI
Exec=/opt/cursor.appimage --no-sandbox
Icon=/opt/cursor.png
Type=Application
Categories=Development;
DESKTOP
        "
    fi
}

# =============================================================================
#  SECTION 2: Terminal & Shell (from setup_dev.sh)
# =============================================================================

install_terminator() {
    if command -v terminator &>/dev/null; then
        log_warn "Terminator is already installed. Skipping."
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

# =============================================================================
#  SECTION 3: Git Setup (from setup_dev.sh)
# =============================================================================

install_git() {
    if command -v git &>/dev/null; then
        log_warn "Git is already installed ($(git --version)). Skipping installation."
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
#  SECTION 4: APT Dev Tools (from setup_dev.sh)
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
        log_warn "All APT dev tools are already installed. Skipping."
        return
    fi

    log_info "The following APT dev tools are not installed: ${missing[*]}"
    if ask_user "Install missing APT dev tools (${missing[*]})?"; then
        try_install "APT dev tools" bash -c "sudo apt update && sudo apt install -y ${missing[*]}"
    fi
}

# =============================================================================
#  SECTION 5: Snap Apps (from setup_dev.sh)
# =============================================================================

install_snap_apps() {
    local apps=(slack spotify)
    for app in "${apps[@]}"; do
        if snap list "$app" &>/dev/null; then
            log_warn "$app (snap) is already installed. Skipping."
        else
            if ask_user "Install $app (snap)?"; then
                try_install "$app" bash -c "sudo snap install $app"
            fi
        fi
    done
}

# =============================================================================
#  SECTION 6: Pixi Package Manager (from setup_dev.sh)
# =============================================================================

install_pixi() {
    if command -v pixi &>/dev/null; then
        log_warn "Pixi is already installed. Skipping."
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
                log_warn "$tool (pixi) is already installed. Skipping."
            else
                try_install "$tool (pixi)" bash -c "pixi global install $tool"
            fi
        done
    fi
}

# =============================================================================
#  SECTION 7: uv Python Installer (from setup_dev.sh)
# =============================================================================

install_uv() {
    if command -v uv &>/dev/null; then
        log_warn "uv is already installed. Skipping."
        return
    fi
    if ask_user "Install uv (Python package installer)?"; then
        try_install "uv" bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi
}

# =============================================================================
#  SECTION 8: Rocker Tools (from setup_dev.sh)
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
                log_warn "$tool is already installed. Skipping."
            else
                try_install "$tool" bash -c "uv tool install $tool"
            fi
        done
    fi
}

# =============================================================================
#  SECTION 9: Rust & Cargo (from setup_dev.sh)
# =============================================================================

install_rust() {
    if command -v rustc &>/dev/null; then
        log_warn "Rust is already installed ($(rustc --version)). Skipping."
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
#  SECTION 10: lazydocker (from setup_dev.sh)
# =============================================================================

install_lazydocker() {
    if command -v lazydocker &>/dev/null; then
        log_warn "lazydocker is already installed. Skipping."
        return
    fi
    if ask_user "Install lazydocker (Docker TUI)?"; then
        try_install "lazydocker" bash -c \
            "curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash"
    fi
}

# =============================================================================
#  SECTION 11: pre-commit (from setup_dev.sh)
# =============================================================================

install_precommit() {
    if command -v pre-commit &>/dev/null; then
        log_warn "pre-commit is already installed. Skipping."
        return
    fi
    if ask_user "Install pre-commit?"; then
        try_install "pre-commit" bash -c "sudo apt-get install -y pre-commit"
    fi
}

# =============================================================================
#  SECTION 12: Earthly (from setup_dev.sh)
# =============================================================================

install_earthly() {
    if command -v earthly &>/dev/null; then
        log_warn "Earthly is already installed. Skipping."
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
#  SECTION 13: Docker (from setup_host.sh)
# =============================================================================

install_docker() {
    if command -v docker &>/dev/null; then
        log_warn "Docker is already installed ($(docker --version)). Skipping."
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
#  SECTION 14: NVIDIA Container Toolkit (from setup_host.sh)
# =============================================================================

install_nvidia_docker() {
    if dpkg -s nvidia-container-toolkit &>/dev/null; then
        log_warn "NVIDIA Container Toolkit is already installed. Skipping."
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
            sudo apt install -y nvidia-docker2 nvidia-container-toolkit
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
        log_warn "Discord is already installed. Skipping."
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
        log_warn "FSearch is already installed. Skipping."
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
        log_warn "Filelight is already installed. Skipping."
        return
    fi
    if ask_user "Install Filelight (disk usage visualizer)?"; then
        try_install "Filelight" bash -c "sudo apt install -y filelight"
    fi
}

install_dolphin() {
    if command -v dolphin &>/dev/null; then
        log_warn "Dolphin file manager is already installed. Skipping."
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
            sudo swapon /swapfile
        "
        swapon --show
    fi
}

# =============================================================================
#  SECTION 18: Stress Test Tools (from stress_test.sh)
# =============================================================================

install_stress_tools() {
    if command -v stress-ng &>/dev/null; then
        log_warn "stress-ng is already installed. Skipping."
        return
    fi
    if ask_user "Install stress-ng (CPU/RAM stress testing)?"; then
        try_install "stress-ng" bash -c "sudo apt install -y stress-ng"
    fi
}

# =============================================================================
#  SECTION 19: System Update
# =============================================================================

system_update() {
    if ask_user "Run full system update & upgrade?"; then
        try_install "System Update" bash -c "sudo apt-get update && sudo apt-get upgrade -y"
    fi
}

# =============================================================================
#  MAIN
# =============================================================================

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

    section "IDE & Browsers"
    install_vscode
    install_chrome
    install_cursor

    section "Terminal & Shell"
    install_terminator

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

    section "System Update"
    system_update

    echo ""
    echo -e "${GREEN}=========================================================${NC}"
    echo -e "${GREEN}  Setup complete! Log file: $LOG_FILE${NC}"
    echo -e "${GREEN}  You may need to restart your machine for all changes.${NC}"
    echo -e "${GREEN}=========================================================${NC}"
}

main "$@"
