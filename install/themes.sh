#!/bin/bash
# Theme and icon installation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

PROJECT_ROOT="$(get_project_root)"

# Flat-Remix GTK is not in Debian/Kali apt: fetch it from the upstream repo
_download_flat_remix_gtk() {
  local dest="$1" variant
  if [[ -d "$dest/Flat-Remix-GTK-Red-Darkest" ]]; then
    log "Flat-Remix-GTK-Red-Darkest already installed"
    return 0
  fi
  log "Downloading Flat-Remix GTK theme from GitHub..."
  local tmp; tmp=$(mktemp -d)
  if git clone -q --depth=1 https://github.com/daniruiz/flat-remix-gtk "$tmp/frgtk"; then
    for variant in Flat-Remix-GTK-Red-Darkest Flat-Remix-GTK-Red-Darkest-Solid; do
      cp -r "$tmp/frgtk/themes/$variant" "$dest/"
    done
    log "Installed Flat-Remix-GTK-Red-Darkest"
  else
    log_warn "Could not download Flat-Remix GTK; install it manually"
  fi
  rm -rf "$tmp"
}

install_gtk_theme() {
  log "Installing GTK themes..."
  
  local theme_source="$PROJECT_ROOT/dot/theme/themes"
  local icon_source="$PROJECT_ROOT/dot/theme/icons"
  local theme_dest="$HOME/.local/share/themes"
  local icon_dest="$HOME/.local/share/icons"
  
  # Create directories
  mkdir -p "$theme_dest" "$icon_dest"
  
  # Copy themes if they exist
  if [[ -d "$theme_source" ]]; then
    cp -r "$theme_source"/* "$theme_dest/" 2>/dev/null || true
    log "GTK themes installed"
  else
    log_warn "Theme source not found: $theme_source"
    _download_flat_remix_gtk "$theme_dest"
  fi

  # Copy icons if they exist
  if [[ -d "$icon_source" ]]; then
    cp -r "$icon_source"/* "$icon_dest/" 2>/dev/null || true
    log "Icons installed"
  else
    log_warn "Icon source not found: $icon_source"
    log_info "Install icons manually or use lxappearance"
    log_info "Current icon theme: Flat-Remix-Red-Dark"
  fi
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
  log_info "  GTK Theme: Flat-Remix-GTK-Red-Darkest"
  log_info "  Icon Theme: Flat-Remix-Red-Dark"
  log_info "  Cursor Theme: Adwaita"
  log_info "  Font: FiraCode Nerd Font Mono Medium 11"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_root
  install_themes
fi
