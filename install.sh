#!/bin/bash

# Global configuration
CONFIG_DIR="$HOME/.bspwn/dot"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +'%Y%m%d%H%M%S').tar.gz"
NVIM_VERSION="v0.11.0"

# Ensure project is in $HOME/.bspwn
setup_project_dir() {
  if [[ "$PWD" != "$HOME/.bspwn" ]]; then
    mkdir -p "$HOME/.bspwn" || error_exit "Failed to create .bspwn directory"
    mv -- * .[!.]* ..?* "$HOME/.bspwn/" 2>/dev/null
    cd "$HOME/.bspwn" || error_exit "Failed to enter .bspwn directory"
    log "Project moved to $HOME/.bspwn"
  fi
}

# Enhanced logging
log() {
  printf "[%s] %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

# Error handling
error_exit() {
  log "ERROR: $1" >&2
  exit 1
}

# Create compressed backup
create_backup() {
  local backup_files=()

  # Collect dotfiles
  while IFS= read -r -d $'\0' file; do
    backup_files+=("$file")
  done < <(find "$CONFIG_DIR" -maxdepth 1 -type f -print0)

  # Collect .config directories
  while IFS= read -r -d $'\0' dir; do
    backup_files+=("$dir")
  done < <(find "$CONFIG_DIR/.config" -maxdepth 1 -type d -print0)

  # Create compressed backup
  tar -czf "$BACKUP_DIR" --ignore-failed-read "${backup_files[@]}" &&
    log "Created compressed backup at $BACKUP_DIR"
}

# Safer symlink creation
link_configs() {
  # Handle dotfiles
  find "$CONFIG_DIR" -maxdepth 1 -type f -exec bash -c '
        for file do
            base_file="${file##*/}"
            ln -sfv "$file" "$HOME/$base_file"
    done' bash {} +

  # Handle .config directories
  find "$CONFIG_DIR/.config" -maxdepth 1 -type d -exec bash -c '
        for dir do
            base_dir="${dir##*/}"
            ln -sfnv "$dir" "$HOME/.config/$base_dir"
    done' bash {} +

  # vim
  cp -rv "$CONFIG_DIR/.vim" "$HOME"

}

# Enhanced package installation
install_packages() {
  local required_packages=(
    # System Utilities
    btm btop htop iftop moreutils shellcheck scrub pcmanfm

    # Desktop Environment & Window Manager
    bspwm picom polybar rofi sxhkd xinput

    # Terminal Utilities
    bat fastfetch gping kitty lsd neovim xclip xsel

    # Media & Graphics
    feh flameshot gimp mpv timg ueberzug vlc sxiv nsxiv mirage

    # Network & Connectivity
    kdeconnect vnstat

    # Security & Privacy
    apg pwgen slock xss-lock

    # Notifications & Appearance
    dmenu dunst libnotify-bin lxappearance pavucontrol pamixer pasystray network-manager network-manager-gnome cbatticon

    # Miscellaneous Utilities
    xdotool brightnessctl calc chrony ncal ranger redshift translate-shell zathura xcalib wmctrl acpid xsettingsd pulseaudio-utils hsetroot pipewire pipewire-pulse pipewire-alsa wireplumber

    # drive backup
    rclone

  )

  log "Updating package list..."
  sudo apt update || error_exit "Failed to update packages"

  log "Installing required packages..."
  sudo apt install -y "${required_packages[@]}" || error_exit "Package installation failed"

  log "Removing existing NeoVim..."
  sudo apt remove --purge -y neovim* || log "No existing NeoVim found"
}

# NeoVim installation
install_neovim() {
  local nvim_url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
  local temp_dir=$(mktemp -d)

  log "Installing NeoVim ${NVIM_VERSION}..."
  wget -q "$nvim_url" -O "$temp_dir/nvim.tar.gz" || error_exit "Failed to download NeoVim"
  tar -xzf "$temp_dir/nvim.tar.gz" -C "$temp_dir" || error_exit "Failed to extract NeoVim"

  sudo install -Dm755 "$temp_dir/nvim-linux-x86_64/bin/nvim" "/usr/local/bin/nvim"
  sudo cp -rv "$temp_dir/nvim-linux-x86_64/share/man/man1/nvim.1" "/usr/local/share/man/man1/"
  sudo cp -rv "$temp_dir/nvim-linux-x86_64/lib" "/lib"

  rm -rf "$temp_dir"
  log "NeoVim installed successfully"
}

install_obsidian() {
  wget -q "https://github.com/obsidianmd/obsidian-releases/releases/download/v1.8.9/obsidian_1.8.9_amd64.deb" -O "/dev/shm/obsidian_1.8.9_amd64.deb"
  sudo dpkg -i "/dev/shm/obsidian_1.8.9_amd64.deb"
}

install_gtk_theme() {
  mkdir -p "$HOME/.local/share"
  sudo cp -rv "$CONFIG_DIR/theme/themes" "$HOME/.local/share/themes"
  sudo cp -rv "$CONFIG_DIR/theme/icons" "$HOME/.local/share/icons"
}

install_fonts() {
  local fonts=("FiraCode" "Hack" "Terminus" "0xProto" "Gohu")
  local tmp_dir="/dev/shm/nerd-fonts"

  mkdir -p "$tmp_dir"

  for font in "${fonts[@]}"; do
    wget -q "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/$font.zip" -O "$tmp_dir/$font.zip" &&
      unzip -q "$tmp_dir/$font.zip" -d "/usr/share/fonts/$font"
  done

  fc-cache -fv # Refresh the font cache
  rm -rf "$tmp_dir"
}

# Install NvChad configuration
install_nvchad() {
  log "Installing NvChad configuration..."
  rm -rf ~/.config/nvim || log "Failed to remove ~/.config/nvim"
  rm -rf ~/.local/state/nvim || log "Failed to remove ~/.local/state/nvim"
  rm -rf ~/.local/share/nvim || log "Failed to remove ~/.local/share/nvim"
  git clone https://github.com/NvChad/starter ~/.config/nvim && nvim
  log "NvChad installed successfully."
}

# Parse command-line arguments and execute corresponding functions
parse_arguments() {
  local full=0 pkg=0 config=0 nvim=0 nvchad=0 fonts=0 theme=0 obsidian=0
  local has_options=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -full)
      full=1
      has_options=1
      ;;
    -pkg)
      pkg=1
      has_options=1
      ;;
    -config)
      config=1
      has_options=1
      ;;
    -nvim)
      nvim=1
      has_options=1
      ;;
    -nvchad)
      nvchad=1
      has_options=1
      ;;
    -fonts)
      fonts=1
      has_options=1
      ;;
    -theme)
      theme=1
      has_options=1
      ;;
    -obsidian)
      obsidian=1
      has_options=1
      ;;
    *) error_exit "Unknown option: $1" ;;
    esac
    shift
  done

  # Print usage and exit if no options were provided
  if [[ $has_options -eq 0 ]]; then
    echo -e "Usage: $0 [OPTIONS]"
    echo -e "Options:"
    echo -e "\t-full      Perform full installation (includes all options below)"
    echo -e "\t-pkg       Install system packages"
    echo -e "\t-config    Link configuration files"
    echo -e "\t-nvim      Install NeoVim"
    echo -e "\t-nvchad    Install NvChad configuration"
    echo -e "\t-fonts     Install fonts"
    echo -e "\t-theme     Install GTK theme and icons"
    echo -e "\t-obsidian  Install Obsidian"
    exit 1
  fi

  # Handle -full flag (overrides others)
  if [[ $full -eq 1 ]]; then
    log "Starting full installation..."
    setup_project_dir
    create_backup
    install_packages
    install_neovim
    install_obsidian
    install_fonts
    link_configs
    log "Full installation completed!"
    log "Backup available at: $BACKUP_DIR"
    return 0
  fi

  # Determine if setup and backup are needed
  local need_setup=0 need_backup=0
  [[ $config -eq 1 || $theme -eq 1 ]] && need_setup=1
  [[ $config -eq 1 ]] && need_backup=1

  # Execute pre-steps
  [[ $need_setup -eq 1 ]] && setup_project_dir
  [[ $need_backup -eq 1 ]] && create_backup

  # Execute requested functions in order
  [[ $pkg -eq 1 ]] && install_packages
  [[ $nvim -eq 1 ]] && install_neovim
  [[ $obsidian -eq 1 ]] && install_obsidian
  [[ $fonts -eq 1 ]] && install_fonts
  [[ $config -eq 1 ]] && link_configs
  [[ $theme -eq 1 ]] && install_gtk_theme
  [[ $nvchad -eq 1 ]] && install_nvchad

  log "Selected operations completed."
}

# Start script execution
parse_arguments "$@"
