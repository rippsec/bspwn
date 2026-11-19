#!/bin/bash
# Theme and icon installation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

PROJECT_ROOT="$(get_project_root)"

# Flat-Remix icons are not in Debian/Kali apt: fetch the variant from the upstream repo
_download_flat_remix_icons() {
  local dest="$1" variant="Flat-Remix-Black-Dark"
  if [[ -d "$dest/$variant" ]]; then
    log "$variant already installed"
    return 0
  fi
  log "Downloading $variant icons from GitHub..."
  local tmp; tmp=$(mktemp -d)
  if git clone -q --depth=1 https://github.com/daniruiz/flat-remix "$tmp/fr"; then
    cp -r "$tmp/fr/$variant" "$dest/"
    command -v gtk-update-icon-cache &>/dev/null \
      && gtk-update-icon-cache -f -t "$dest/$variant" &>/dev/null || true
    log "Installed $variant"
  else
    log_warn "Could not download Flat-Remix icons; install $variant manually"
  fi
  rm -rf "$tmp"
}

install_gtk_theme() {
  log "Installing GTK theme and icons..."

  local theme_source="$PROJECT_ROOT/dot/theme/themes"
  local theme_dest="$HOME/.local/share/themes"
  local icon_dest="$HOME/.local/share/icons"

  mkdir -p "$theme_dest" "$icon_dest"

  # Custom Flat-Remix-GTK-Slate-Darkest ships in the repo
  if [[ -d "$theme_source" ]]; then
    cp -r "$theme_source"/* "$theme_dest/"
    log "GTK theme installed (Flat-Remix-GTK-Slate-Darkest)"
  else
    log_warn "Theme source not found: $theme_source"
  fi

  _download_flat_remix_icons "$icon_dest"
}

install_cursor_theme() {
  log "Setting up cursor theme..."
  
  local cursor_dir="$HOME/.icons/default"
  mkdir -p "$cursor_dir"
  
  # Create index.theme for Adwaita cursor
  cat > "$cursor_dir/index.theme" << 'EOF'
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=Adwaita
EOF
  
  log "Cursor theme set to Adwaita"
}

setup_qt_theme() {
  log "Setting up Qt theme environment..."

  local export_line='export QT_QPA_PLATFORMTHEME="qt5ct"'

  # Prefer ~/.zprofile for zsh; fall back to ~/.profile for other shells
  local profile_file="$HOME/.zprofile"
  [[ ! -f "$profile_file" && -f "$HOME/.profile" ]] && profile_file="$HOME/.profile"

  if ! grep -q 'QT_QPA_PLATFORMTHEME' "$profile_file" 2>/dev/null; then
    echo "$export_line" >> "$profile_file"
    log "Added QT_QPA_PLATFORMTHEME to $profile_file"
  else
    log "QT_QPA_PLATFORMTHEME already set in $profile_file"
  fi

  log_info "Qt5/Qt6 theme config is in ~/.config/qt5ct and ~/.config/qt6ct"
  log_info "Use qt5ct or qt6ct to modify if needed"
}

install_themes() {
  install_gtk_theme
  install_cursor_theme
  setup_qt_theme
  
  log "Theme installation completed!"
  log_info "Current configuration:"
  log_info "  GTK Theme: Flat-Remix-GTK-Slate-Darkest"
  log_info "  Icon Theme: Flat-Remix-Black-Dark"
  log_info "  Cursor Theme: Adwaita"
  log_info "  Font: FiraCode Nerd Font Mono Medium 11"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_root
  install_themes
fi
