#!/bin/bash
# Configuration file linking script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

PROJECT_ROOT="$(get_project_root)"
CONFIG_DIR="$PROJECT_ROOT/dot"

link_dotfiles() {
  log "Linking dotfiles to home directory..."
  
  # Link root dotfiles (.bashrc, .zshrc, etc.)
  local dotfiles=(
    ".bashrc"
    ".gtkrc-2.0"
    ".zshrc"
    ".zsh"
    ".tmux.conf"
    ".vimrc"
    ".vim"
    ".xinitrc"
    ".Xresources"
    ".xsession"
    ".xbindkeysrc"
    ".latexmkrc"
  )
  
  for file in "${dotfiles[@]}"; do
    local source="$CONFIG_DIR/$file"
    local target="$HOME/$file"
    
    if [[ -e "$source" ]]; then
      safe_symlink "$source" "$target"
    fi
  done
}

link_config_dirs() {
  log "Linking .config directories..."
  
  # List of config directories to link
  local config_dirs=(
    "bspwm"
    "sxhkd"
    "polybar"
    "kitty"
    "dunst"
    "picom"
    "rofi"
    "ranger"
    "zathura"
    "alacritty"
    "fastfetch"
    "gtk-3.0"
    "gtk-4.0"
    "qt5ct"
    "qt6ct"
    "fontconfig"
    "skippy-xd"
    "i3lock"
    "jgmenu"
  )
  
  mkdir -p "$HOME/.config"
  
  for dir in "${config_dirs[@]}"; do
    local source="$CONFIG_DIR/.config/$dir"
    local target="$HOME/.config/$dir"
    
    if [[ -d "$source" ]]; then
      safe_symlink "$source" "$target"
    fi
  done
}

link_nvim_config() {
  log "Linking Neovim configuration..."
  
  local nvim_source="$CONFIG_DIR/.config/nvim"
  local nvim_target="$HOME/.config/nvim"
  
  if [[ -d "$nvim_source" ]]; then
    # Backup existing nvim config
    if [[ -d "$nvim_target" && ! -L "$nvim_target" ]]; then
      backup_if_exists "$nvim_target"
    fi
    
    safe_symlink "$nvim_source" "$nvim_target"
    log "Neovim config linked (LazyVim-based)"
  else
    log_warn "Neovim config not found in dotfiles"
  fi
}

setup_permissions() {
  log "Setting executable permissions..."
  
  # Make scripts executable
  local script_dirs=(
    "$CONFIG_DIR/.config/bspwm"
    "$CONFIG_DIR/.config/sxhkd/scripts"
    "$CONFIG_DIR/.config/polybar"
    "$CONFIG_DIR/.config/polybar/scripts"
  )
  
  for dir in "${script_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      find "$dir" -type f \( -name "*.sh" -o ! -name "*.*" \) -exec chmod +x {} \;
    fi
  done
  
  # Make bspwmrc executable
  [[ -f "$CONFIG_DIR/.config/bspwm/bspwmrc" ]] && chmod +x "$CONFIG_DIR/.config/bspwm/bspwmrc"
  [[ -f "$CONFIG_DIR/.config/bspwm/start" ]] && chmod +x "$CONFIG_DIR/.config/bspwm/start"
}

link_configs() {
  link_dotfiles
  link_config_dirs
  link_nvim_config
  setup_permissions
  
  log "Configuration linking completed!"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_root
  link_configs
fi
