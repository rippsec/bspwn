#!/bin/bash
# Package installation script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

install_packages() {
  # Packages available in Debian/Kali repos (skippy-xd, rclone removed for compatibility)
  # suckless-tools provides dmenu, slock, wmname on many distros
  local required_packages=(
    # System Utilities
    btm btop htop iftop moreutils shellcheck scrub pcmanfm

    # Desktop Environment & Window Manager
    bspwm picom polybar rofi sxhkd xinput suckless-tools wmctrl

    # Terminal Utilities
    bat fastfetch gping kitty lsd xclip xsel tmux

    # Media & Graphics
    feh flameshot gimp mpv timg vlc nsxiv mirage

    # Network & Connectivity
    kdeconnect vnstat

    # Security & Privacy
    apg pwgen xss-lock

    # Notifications & Appearance
    dunst libnotify-bin lxappearance pavucontrol pamixer pasystray
    network-manager network-manager-gnome cbatticon

    # System Configuration
    xdotool brightnessctl calc chrony ncal ranger redshift translate-shell
    zathura xcalib acpid xsettingsd pulseaudio-utils hsetroot
    pipewire pipewire-pulse pipewire-alsa wireplumber lxpolkit

    # X11 utilities
    xbindkeys

    # Qt/GTK theming
    qt5ct qt6ct
  )

  log "Updating package list..."
  sudo apt update || error_exit "Failed to update packages"

  log "Installing required packages..."
  if sudo apt install -y "${required_packages[@]}"; then
    log "Package installation completed!"
  else
    log_warn "Some packages may have failed; continuing."
  fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_root
  install_packages
fi
