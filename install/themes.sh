#!/bin/bash
# Theme and icon installation script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

PROJECT_ROOT="$(get_project_root)"

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
    cp -rv "$theme_source"/* "$theme_dest/" 2>/dev/null || true
    log "GTK themes installed"
  else
    log_warn "Theme source not found: $theme_source"
    log_info "Install themes manually or use lxappearance to download"
    log_info "Current theme: Adwaita-dark"
  fi
  
  # Copy icons if they exist
  if [[ -d "$icon_source" ]]; then
    cp -rv "$icon_source"/* "$icon_dest/" 2>/dev/null || true
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
  
  # Ensure QT_QPA_PLATFORMTHEME is set
  local profile_file="$HOME/.profile"
  local export_line='export QT_QPA_PLATFORMTHEME="qt5ct"'
  
  if ! grep -q 'QT_QPA_PLATFORMTHEME' "$profile_file" 2>/dev/null; then
    echo "$export_line" >> "$profile_file"
    log "Added QT_QPA_PLATFORMTHEME to ~/.profile"
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
  log_info "  GTK Theme: Adwaita-dark"
  log_info "  Icon Theme: Flat-Remix-Red-Dark"
  log_info "  Cursor Theme: Adwaita"
  log_info "  Font: AdwaitaMono Nerd Font Mono 11"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_root
  install_themes
fi
