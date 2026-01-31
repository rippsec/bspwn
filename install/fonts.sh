#!/bin/bash
# Font installation script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Nerd Fonts version
NERD_FONTS_VERSION="v3.4.0"

install_fonts() {
  local fonts=(
    "AdwaitaMono"     # Primary font (AdwaitaMono Nerd Font Mono)
    "Symbols"         # For icons in polybar, etc.
    "FiraCode"        # Alternative monospace font
    "Hack"            # Backup monospace font
    "0xProto"         # Programming font
  )
  
  local tmp_dir="/dev/shm/nerd-fonts"
  local font_dir="/usr/share/fonts/nerd-fonts"

  log "Creating temporary directory..."
  mkdir -p "$tmp_dir"
  
  log "Creating font directory..."
  sudo mkdir -p "$font_dir"

  for font in "${fonts[@]}"; do
    local url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${font}.zip"
    local zip_file="$tmp_dir/${font}.zip"
    local extract_dir="$font_dir/${font}"
    
    log "Downloading $font..."
    if download_file "$url" "$zip_file"; then
      log "Extracting $font..."
      sudo mkdir -p "$extract_dir"
      sudo unzip -q -o "$zip_file" -d "$extract_dir"
      log "Installed: $font"
    else
      log_warn "Failed to download $font"
    fi
  done

  log "Refreshing font cache..."
  fc-cache -fv

  log "Cleaning up..."
  rm -rf "$tmp_dir"

  log "Font installation completed!"
  log_info "Primary font: AdwaitaMono Nerd Font Mono"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_root
  install_fonts
fi
