#!/bin/bash
# Package installation script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

install_packages() {
  local required_packages=(
    # System Utilities
    btm btop htop iftop moreutils shellcheck scrub pcmanfm

    # Desktop Environment & Window Manager
    bspwm picom polybar rofi sxhkd xinput wmname wmctrl

    # Terminal Utilities
    bat fastfetch gping kitty lsd xclip xsel tmux

    # Media & Graphics
    feh flameshot gimp mpv timg vlc nsxiv mirage

    # Network & Connectivity
    kdeconnect vnstat

    # Security & Privacy
    apg pwgen slock xss-lock

    # Notifications & Appearance
    dmenu dunst libnotify-bin lxappearance pavucontrol pamixer pasystray 
    network-manager network-manager-gnome cbatticon

    # System Configuration
    xdotool brightnessctl calc chrony ncal ranger redshift translate-shell 
    zathura xcalib acpid xsettingsd pulseaudio-utils hsetroot 
    pipewire pipewire-pulse pipewire-alsa wireplumber lxpolkit

    # X11 utilities
    xbindkeys skippy-xd
    
    # Drive backup
    rclone

    # Qt/GTK theming
    qt5ct qt6ct
  )

  log "Updating package list..."
  sudo apt update || error_exit "Failed to update packages"

  log "Installing required packages..."
  sudo apt install -y "${required_packages[@]}" || log_warn "Some packages may have failed to install"

  log "Package installation completed!"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_root
  install_packages
fi
