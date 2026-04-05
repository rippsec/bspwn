#!/bin/bash
# Font installation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Nerd Fonts version
NERD_FONTS_VERSION="v3.4.0"

install_fonts() {
  # Each entry: "DisplayName|ZipFilename|fc-list grep pattern"
  # DisplayName   — used for the install dir and log messages
  # ZipFilename   — actual filename on the GitHub release (without .zip)
  # grep pattern  — passed to `fc-list | grep -qi` to detect if already installed
  local font_specs=(
    "AdwaitaMono|AdwaitaMono|AdwaitaMono Nerd Font"
    "Symbols|NerdFontsSymbolsOnly|Symbols Nerd Font"
    "FiraCode|FiraCode|FiraCode Nerd Font"
    "Hack|Hack|Hack Nerd Font"
    "0xProto|0xProto|0xProto Nerd Font"
  )

  local tmp_dir="/dev/shm/nerd-fonts"
  local font_dir="/usr/share/fonts/nerd-fonts"

  mkdir -p "$tmp_dir"
  sudo mkdir -p "$font_dir"

  # Determine which fonts need installing
  local to_install=()
  for spec in "${font_specs[@]}"; do
    local name="${spec%%|*}"
    local rest="${spec#*|}"
    local pattern="${rest#*|}"
    if fc-list | grep -qi "$pattern"; then
      log "$name: already installed, skipping"
    else
      to_install+=("$spec")
    fi
  done

  if [[ ${#to_install[@]} -eq 0 ]]; then
    log "All fonts already installed."
    rm -rf "$tmp_dir"
    return 0
  fi

  # Download all missing fonts in parallel
  log "Downloading ${#to_install[@]} font(s) in parallel..."
  for spec in "${to_install[@]}"; do
    local name="${spec%%|*}"
    local rest="${spec#*|}"
    local zipname="${rest%%|*}"
    local url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${zipname}.zip"
    download_file "$url" "$tmp_dir/${name}.zip" &
  done
  wait || log_warn "One or more font downloads failed"

  # Extract
  for spec in "${to_install[@]}"; do
    local name="${spec%%|*}"
    local zip_file="$tmp_dir/${name}.zip"
    if [[ -f "$zip_file" ]]; then
      log "Extracting $name..."
      sudo mkdir -p "$font_dir/$name"
      sudo unzip -q -o "$zip_file" -d "$font_dir/$name"
      log "Installed: $name"
    else
      log_warn "Skipping $name — download failed"
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
