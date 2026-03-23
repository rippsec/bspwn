#!/bin/bash
# Font installation script

set -euo pipefail

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

  mkdir -p "$tmp_dir"
  sudo mkdir -p "$font_dir"

  # Determine which fonts actually need installing
  local to_install=()
  for font in "${fonts[@]}"; do
    if fc-list | grep -qi "$font"; then
      log "$font: already installed, skipping"
    else
      to_install+=("$font")
    fi
  done

  if [[ ${#to_install[@]} -eq 0 ]]; then
    log "All fonts already installed."
    rm -rf "$tmp_dir"
    return 0
  fi

  # Download all missing fonts in parallel
  log "Downloading ${#to_install[@]} font(s) in parallel..."
  for font in "${to_install[@]}"; do
    local url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${font}.zip"
    download_file "$url" "$tmp_dir/${font}.zip" &
  done
  wait || log_warn "One or more font downloads failed"

  # Extract sequentially (sudo in parallel is fine but ordering looks cleaner)
  for font in "${to_install[@]}"; do
    local zip_file="$tmp_dir/${font}.zip"
    if [[ -f "$zip_file" ]]; then
      log "Extracting $font..."
      sudo mkdir -p "$font_dir/$font"
      sudo unzip -q -o "$zip_file" -d "$font_dir/$font"
      log "Installed: $font"
    else
      log_warn "Skipping $font — download failed"
    fi
  done

  log "Refreshing font cache..."
  fc-cache -f

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
