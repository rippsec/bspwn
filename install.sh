#!/bin/bash
#
# ██████╗ ███████╗██████╗ ██╗    ██╗███╗   ██╗
# ██╔══██╗██╔════╝██╔══██╗██║    ██║████╗  ██║
# ██████╔╝███████╗██████╔╝██║ █╗ ██║██╔██╗ ██║
# ██╔══██╗╚════██║██╔═══╝ ██║███╗██║██║╚██╗██║
# ██████╔╝███████║██║     ╚███╔███╔╝██║ ╚████║
# ╚═════╝ ╚══════╝╚═╝      ╚══╝╚══╝ ╚═╝  ╚═══╝
#
# BSPWM Dotfiles Installation Script
# A modular installer for bspwm rice configuration
#

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/install"

# Source utilities
source "$INSTALL_DIR/utils.sh"

# Configuration
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +'%Y%m%d%H%M%S')"
NVIM_VERSION="v0.11.0"
OBSIDIAN_VERSION="1.8.9"

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

# Ensure project is in $HOME/.bspwn
setup_project_dir() {
  if [[ "$PWD" != "$HOME/.bspwn" && "$SCRIPT_DIR" != "$HOME/.bspwn" ]]; then
    log "Moving project to $HOME/.bspwn..."
    mkdir -p "$HOME/.bspwn" || error_exit "Failed to create .bspwn directory"
    cp -r "$SCRIPT_DIR"/* "$HOME/.bspwn/" 2>/dev/null || true
    cp -r "$SCRIPT_DIR"/.[!.]* "$HOME/.bspwn/" 2>/dev/null || true
    cd "$HOME/.bspwn" || error_exit "Failed to enter .bspwn directory"
    SCRIPT_DIR="$HOME/.bspwn"
    INSTALL_DIR="$SCRIPT_DIR/install"
    log "Project moved to $HOME/.bspwn"
  fi
}

# Create compressed backup of existing configs
create_backup() {
  log "Creating backup..."
  
  local backup_items=()
  local config_dirs=("bspwm" "sxhkd" "polybar" "kitty" "dunst" "picom" "rofi" "nvim")
  
  # Add existing config directories
  for dir in "${config_dirs[@]}"; do
    [[ -d "$HOME/.config/$dir" ]] && backup_items+=("$HOME/.config/$dir")
  done
  
  # Add dotfiles
  for file in .bashrc .zshrc .tmux.conf .vimrc .xinitrc .Xresources; do
    [[ -f "$HOME/$file" ]] && backup_items+=("$HOME/$file")
  done
  
  if [[ ${#backup_items[@]} -gt 0 ]]; then
    tar -czf "$BACKUP_DIR.tar.gz" --ignore-failed-read "${backup_items[@]}" 2>/dev/null || true
    log "Backup created at: $BACKUP_DIR.tar.gz"
  else
    log_info "No existing configs to backup"
  fi
}

# Install Obsidian
install_obsidian() {
  log "Installing Obsidian ${OBSIDIAN_VERSION}..."
  
  local deb_url="https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/obsidian_${OBSIDIAN_VERSION}_amd64.deb"
  local deb_file="/tmp/obsidian_${OBSIDIAN_VERSION}_amd64.deb"
  
  download_file "$deb_url" "$deb_file" || error_exit "Failed to download Obsidian"
  sudo dpkg -i "$deb_file" || sudo apt-get install -f -y
  rm -f "$deb_file"
  
  log "Obsidian installed successfully!"
}

# =============================================================================
# MODULAR SCRIPT WRAPPERS
# =============================================================================

run_packages() {
  source "$INSTALL_DIR/packages.sh"
  install_packages
}

run_fonts() {
  source "$INSTALL_DIR/fonts.sh"
  install_fonts
}

run_themes() {
  source "$INSTALL_DIR/themes.sh"
  install_themes
}

run_configs() {
  source "$INSTALL_DIR/configs.sh"
  link_configs
}

run_nvim() {
  source "$INSTALL_DIR/nvim.sh"
  install_nvim_full
}

# Ly display manager (run last; requires logout to take effect)
install_ly() {
  log "=== Installing Ly display manager (last; logout required to use) ==="
  local project_root="${SCRIPT_DIR}"
  local system_ly="$project_root/system/etc/ly"
  if [[ ! -d "$system_ly" ]]; then
    log_warn "Ly config not found at $system_ly, skipping Ly setup"
    return 0
  fi
  if command -v ly &>/dev/null; then
    log "Ly is already installed"
  else
    log "Installing Ly display manager..."
    if ! sudo apt-get install -y ly 2>/dev/null; then
      log_warn "Package 'ly' not in repo (e.g. on Kali). Copying config anyway; install ly from source or another repo to use."
    fi
  fi
  log "Installing Ly configuration to /etc/ly..."
  sudo mkdir -p /etc/ly
  sudo cp -r "$system_ly"/* /etc/ly/ 2>/dev/null || true
  sudo chmod +x /etc/ly/setup.sh 2>/dev/null || true
  if command -v ly &>/dev/null; then
    log "Enabling Ly (active after next logout)..."
    sudo systemctl enable ly 2>/dev/null || log_warn "Could not enable ly service"
    log_info "Ly is enabled. Log out to use Ly; then select bspwm session."
  else
    log_info "Ly config is in /etc/ly. Install and enable ly when ready, then log out to use it."
  fi
}

run_ly() {
  install_ly
}

# =============================================================================
# FULL INSTALLATION
# =============================================================================

full_install() {
  log "Starting full installation..."
  echo ""
  
  setup_project_dir
  create_backup
  
  log "=== Installing Packages ==="
  run_packages
  echo ""
  
  log "=== Installing Fonts ==="
  run_fonts
  echo ""
  
  log "=== Linking Configurations ==="
  run_configs
  echo ""
  
  log "=== Installing Themes (GTK/Qt/cursor) ==="
  run_themes
  echo ""
  
  log "=== Installing Neovim ==="
  run_nvim
  echo ""
  
  log "=== Ly display manager (last; logout to use) ==="
  run_ly
  echo ""
  
  log "Full installation completed!"
  log_info "Backup available at: $BACKUP_DIR.tar.gz"
  log_info ""
  log_info "Next steps:"
  log_info "  1. Log out — Ly is enabled; select 'bspwm' at the login"
  log_info "  2. Run 'nvim' once to complete plugin installation"
  log_info "  3. Use 'lxappearance' to verify GTK theme"
  log_info "  4. Use 'qt5ct'/'qt6ct' to verify Qt theme"
}

# =============================================================================
# USAGE AND ARGUMENT PARSING
# =============================================================================

show_usage() {
  cat << EOF
BSPWM Dotfiles Installation Script

Usage: $0 [OPTIONS]

Options:
  -full       Perform full installation (recommended for new setups)
  -pkg        Install system packages only
  -fonts      Install fonts only
  -themes     Install GTK/Qt themes only
  -config     Link configuration files only
  -nvim       Install Neovim only
  -obsidian   Install Obsidian only
  -backup     Create backup of existing configs only
  -ly         Install Ly display manager only (do last; logout to use)
  -h, --help  Show this help message

Examples:
  $0 -full              # Complete installation
  $0 -pkg -fonts        # Install packages and fonts
  $0 -config            # Just link configs (for updates)

Modular Scripts (in ./install/):
  packages.sh   - Package installation
  fonts.sh      - Font installation  
  themes.sh     - Theme setup
  configs.sh    - Configuration linking
  nvim.sh       - Neovim installation
  utils.sh      - Shared utilities

EOF
}

parse_arguments() {
  local has_options=0
  local do_full=0 do_pkg=0 do_fonts=0 do_themes=0 do_config=0 do_nvim=0 do_obsidian=0 do_backup=0 do_ly=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -full)     do_full=1; has_options=1 ;;
      -pkg)      do_pkg=1; has_options=1 ;;
      -fonts)    do_fonts=1; has_options=1 ;;
      -themes)   do_themes=1; has_options=1 ;;
      -config)   do_config=1; has_options=1 ;;
      -nvim)     do_nvim=1; has_options=1 ;;
      -obsidian) do_obsidian=1; has_options=1 ;;
      -backup)   do_backup=1; has_options=1 ;;
      -ly)       do_ly=1; has_options=1 ;;
      -h|--help) show_usage; exit 0 ;;
      *) log_error "Unknown option: $1"; show_usage; exit 1 ;;
    esac
    shift
  done

  # Show usage if no options
  if [[ $has_options -eq 0 ]]; then
    show_usage
    exit 1
  fi

  # Full installation
  if [[ $do_full -eq 1 ]]; then
    full_install
    return 0
  fi

  # Setup project dir if needed
  if [[ $do_config -eq 1 || $do_themes -eq 1 ]]; then
    setup_project_dir
  fi

  # Create backup if requested or before config changes
  if [[ $do_backup -eq 1 || $do_config -eq 1 ]]; then
    create_backup
  fi

  # Execute requested operations in order (ly last when combined with others)
  [[ $do_pkg -eq 1 ]]      && run_packages
  [[ $do_fonts -eq 1 ]]    && run_fonts
  [[ $do_config -eq 1 ]]   && run_configs
  [[ $do_themes -eq 1 ]]   && run_themes
  [[ $do_nvim -eq 1 ]]     && run_nvim
  [[ $do_obsidian -eq 1 ]] && install_obsidian
  [[ $do_ly -eq 1 ]]       && run_ly

  log "Selected operations completed!"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
  # Don't run as root
  if [[ $EUID -eq 0 ]]; then
    error_exit "This script should not be run as root. Use sudo when necessary."
  fi
  
  parse_arguments "$@"
}

main "$@"
