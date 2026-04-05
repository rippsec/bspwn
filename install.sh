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

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/install"

# Source utilities
source "$INSTALL_DIR/utils.sh"

# Configuration
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +'%Y%m%d%H%M%S')"
OBSIDIAN_VERSION="1.8.9"

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

# Ensure project is in $HOME/.bspwn
setup_project_dir() {
  if [[ "$SCRIPT_DIR" != "$HOME/.bspwn" ]]; then
    log "Copying project to $HOME/.bspwn (excluding .git)..."
    mkdir -p "$HOME/.bspwn" || error_exit "Failed to create .bspwn directory"
    if command -v rsync &>/dev/null; then
      rsync -a --exclude='.git' "$SCRIPT_DIR/" "$HOME/.bspwn/"
    else
      # rsync not available — fall back to cp but skip .git
      find "$SCRIPT_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' \
        -exec cp -r {} "$HOME/.bspwn/" \;
    fi
    SCRIPT_DIR="$HOME/.bspwn"
    INSTALL_DIR="$SCRIPT_DIR/install"
    log "Project copied to $HOME/.bspwn"
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

# Install zig (required to build ly from source)
# Downloads the latest stable zig toolchain to /usr/local/zig and symlinks to /usr/local/bin/zig
_install_zig() {
  local required_version="0.15.2"
  local zig_tarball="zig-x86_64-linux-${required_version}.tar.xz"
  local zig_url="https://ziglang.org/download/${required_version}/${zig_tarball}"

  # Skip if correct version already installed
  if command -v zig &>/dev/null && zig version 2>/dev/null | grep -q "^${required_version}$"; then
    log "zig ${required_version} already installed"
    return 0
  fi

  log "Installing zig ${required_version}..."
  local tmp_dir
  tmp_dir=$(mktemp -d)
  download_file "$zig_url" "$tmp_dir/${zig_tarball}" || { log_warn "Failed to download zig"; rm -rf "$tmp_dir"; return 1; }
  sudo rm -rf /usr/local/zig
  sudo mkdir -p /usr/local/zig
  sudo tar -xJf "$tmp_dir/${zig_tarball}" -C /usr/local/zig --strip-components=1
  sudo ln -sfv /usr/local/zig/zig /usr/local/bin/zig
  rm -rf "$tmp_dir"
  log "zig $(zig version) installed"
}

# Ly display manager (run last; requires logout to take effect)
# Builds from source because ly is not in Debian/trixie repos.
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
    log "ly not in apt repos — building from source..."

    # Build deps
    sudo apt-get install -y --no-install-recommends \
      libpam0g-dev libxcb-xkb-dev git || log_warn "Some ly build deps failed"

    _install_zig || { log_warn "zig install failed; skipping ly build"; return 0; }

    local build_dir
    build_dir=$(mktemp -d)
    log "Cloning ly..."
    git clone --depth=1 https://github.com/fairyglade/ly "$build_dir/ly" \
      || { log_warn "Failed to clone ly"; rm -rf "$build_dir"; return 0; }

    log "Building ly (this may take a few minutes)..."
    pushd "$build_dir/ly" > /dev/null
    if ! zig build; then
      log_warn "ly build failed"
      popd > /dev/null
      sudo rm -rf "$build_dir" 2>/dev/null || rm -rf "$build_dir" 2>/dev/null || true
      return 0
    fi
    # installexe copies binary + systemd service to --prefix (default /usr/local)
    sudo zig build installexe -Dinit_system=systemd \
      || log_warn "ly installexe step failed; placing binary manually"
    popd > /dev/null

    # Fallback: manually place binary + service if installexe didn't work
    if ! command -v ly &>/dev/null && [[ -f "$build_dir/ly/zig-out/bin/ly" ]]; then
      sudo install -Dm755 "$build_dir/ly/zig-out/bin/ly" /usr/local/bin/ly
    fi
    # Service file locations vary by ly version
    local svc=""
    for f in "$build_dir/ly/res/ly.service" "$build_dir/ly/zig-out/lib/systemd/system/ly.service"; do
      [[ -f "$f" ]] && svc="$f" && break
    done
    if [[ -n "$svc" ]]; then
      sudo install -Dm644 "$svc" /etc/systemd/system/ly.service
    elif [[ -f "$project_root/system/etc/systemd/system/ly.service" ]]; then
      sudo install -Dm644 "$project_root/system/etc/systemd/system/ly.service" \
        /etc/systemd/system/ly.service
    fi

    sudo rm -rf "$build_dir" 2>/dev/null || true
  fi

  log "Installing Ly configuration to /etc/ly..."
  sudo mkdir -p /etc/ly
  sudo cp -r "$system_ly"/* /etc/ly/ 2>/dev/null || true
  sudo chmod +x /etc/ly/setup.sh 2>/dev/null || true

  if command -v ly &>/dev/null; then
    log "Enabling Ly (active after next logout)..."
    # Disable any other DM first to avoid conflicts
    for dm in lightdm gdm3 sddm; do
      systemctl is-enabled "$dm" &>/dev/null && sudo systemctl disable "$dm" 2>/dev/null && log "Disabled $dm"
    done
    sudo systemctl enable ly 2>/dev/null || log_warn "Could not enable ly service"
    log_info "Ly is enabled. Log out to use Ly; then select bspwm session."
  else
    log_warn "ly binary not found after build — config placed in /etc/ly for manual setup"
  fi
}

run_ly() {
  install_ly
}

# Phase 7.2 — system-wide files: ACPI, X11, bspwm session entry, TLP, pipewire autostart
install_system_files() {
  local project_root="${SCRIPT_DIR}"

  # ACPI lid-close / power-button handlers
  if [[ -d "$project_root/system/etc/acpi" ]]; then
    log "Installing ACPI handlers..."
    sudo cp -r "$project_root/system/etc/acpi/"* /etc/acpi/ 2>/dev/null || true
    sudo chmod +x /etc/acpi/lid.sh /etc/acpi/powerbtn-acpi-support.sh 2>/dev/null || true
    sudo systemctl enable --now acpid 2>/dev/null || log_warn "Could not enable acpid"
  fi

  # X11 monitor / GPU config (TearFree)
  if [[ -d "$project_root/system/etc/X11/xorg.conf.d" ]]; then
    log "Installing X11 config (TearFree, 1600x900)..."
    sudo mkdir -p /etc/X11/xorg.conf.d
    sudo cp "$project_root/system/etc/X11/xorg.conf.d/10-monitor.conf" \
            /etc/X11/xorg.conf.d/10-monitor.conf
  fi

  # bspwm session entry for Ly / any DM
  log "Creating bspwm.desktop session entry..."
  sudo mkdir -p /usr/share/xsessions
  sudo bash -c 'cat > /usr/share/xsessions/bspwm.desktop << EOF
[Desktop Entry]
Name=bspwm
Comment=Binary Space Partitioning Window Manager
Exec=bspwm
Type=Application
EOF'

  # sysctl performance tuning (vm, inotify, network, perf_event)
  if [[ -f "$project_root/system/etc/sysctl.d/99-rip.conf" ]]; then
    log "Installing sysctl tuning (99-rip.conf)..."
    sudo mkdir -p /etc/sysctl.d
    sudo cp "$project_root/system/etc/sysctl.d/99-rip.conf" /etc/sysctl.d/99-rip.conf
    sudo sysctl --system 2>/dev/null || log_warn "sysctl --system had warnings (non-fatal)"
  fi

  # TLP drop-in: governor, battery thresholds, USB, audio, PCIe ASPM
  if [[ -f "$project_root/system/etc/tlp.d/01-rip.conf" ]]; then
    log "Installing TLP drop-in (01-rip.conf)..."
    sudo mkdir -p /etc/tlp.d
    sudo cp "$project_root/system/etc/tlp.d/01-rip.conf" /etc/tlp.d/01-rip.conf
  fi

  # TLP (ThinkPad power management) — enable after drop-in is in place
  if command -v tlp &>/dev/null; then
    log "Enabling TLP..."
    sudo systemctl enable --now tlp 2>/dev/null || log_warn "Could not enable TLP"
    sudo tlp start 2>/dev/null || log_warn "TLP restart had warnings (non-fatal)"
    # Disable conflicting power-profiles-daemon if present
    systemctl is-enabled power-profiles-daemon &>/dev/null \
      && sudo systemctl disable --now power-profiles-daemon 2>/dev/null \
      && log "Disabled power-profiles-daemon (conflicts with TLP)"
  fi

  # zram compressed swap buffer (2GB zstd, priority 100 > LVM swap)
  if [[ -f "$project_root/system/etc/systemd/zram-generator.conf" ]]; then
    log "Installing zram-generator config (2GB zstd, active on next boot)..."
    sudo cp "$project_root/system/etc/systemd/zram-generator.conf" \
            /etc/systemd/zram-generator.conf
    log_info "zram swap will be active after next reboot"
  fi

  # irqbalance — distribute IRQs across all 4 CPUs
  if command -v irqbalance &>/dev/null; then
    log "Enabling irqbalance..."
    sudo systemctl enable --now irqbalance 2>/dev/null || log_warn "Could not enable irqbalance"
  fi

  # earlyoom — fast OOM prevention
  if command -v earlyoom &>/dev/null; then
    log "Enabling earlyoom..."
    sudo systemctl enable --now earlyoom 2>/dev/null || log_warn "Could not enable earlyoom"
  fi

  # Ly service file — ensure it's in place for fresh builds
  if [[ -f "$project_root/system/etc/systemd/system/ly.service" ]] \
     && [[ ! -f /etc/systemd/system/ly.service ]]; then
    log "Installing ly.service..."
    sudo install -Dm644 "$project_root/system/etc/systemd/system/ly.service" \
      /etc/systemd/system/ly.service
    sudo systemctl daemon-reload 2>/dev/null || true
  fi

  # Firefox user.js — deploy to all profiles (VA-API, WebRender, process limits)
  if [[ -f "$project_root/system/firefox/user.js" ]]; then
    local profiles_ini="$HOME/.mozilla/firefox/profiles.ini"
    if [[ -f "$profiles_ini" ]]; then
      # Deploy to every profile path listed in profiles.ini
      local deployed=0
      while IFS='=' read -r key val; do
        [[ "$key" == "Path" ]] || continue
        local ff_dir="$HOME/.mozilla/firefox/$val"
        mkdir -p "$ff_dir"
        cp "$project_root/system/firefox/user.js" "$ff_dir/user.js"
        log "Firefox user.js -> $ff_dir"
        (( deployed++ )) || true
      done < "$profiles_ini"
      [[ $deployed -eq 0 ]] && log_warn "No profiles found in profiles.ini"
    else
      log_warn "Firefox profiles.ini not found; launch Firefox once then re-run -system"
    fi
  fi

  # PipeWire — enable for current user so audio works on first login
  log "Enabling PipeWire user services..."
  systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null \
    || log_warn "Could not enable PipeWire user services (will auto-start via XDG autostart)"

  log "System files installed."
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
  
  log "=== System files (ACPI, X11, bspwm session) ==="
  install_system_files
  echo ""

  log "=== Ly display manager (last; logout to use) ==="
  run_ly
  echo ""

  log "Full installation completed!"
  log_info "Backup available at: $BACKUP_DIR.tar.gz"
  echo ""
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
  -system     Install system files (ACPI, X11, bspwm session, TLP, PipeWire)
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
  local do_full=0 do_pkg=0 do_fonts=0 do_themes=0 do_config=0 do_nvim=0 do_obsidian=0 do_backup=0 do_ly=0 do_system=0

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
      -system)   do_system=1; has_options=1 ;;
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
  [[ $do_system -eq 1 ]]   && install_system_files
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
