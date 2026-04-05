#!/bin/bash
# Package installation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

install_packages() {
  # Packages available in Debian/Kali repos (skippy-xd, rclone removed for compatibility)
  # suckless-tools provides dmenu, slock, wmname on many distros
  local required_packages=(
    # System Utilities
    btm btop htop iftop moreutils shellcheck scrub pcmanfm

    # Desktop Environment & Window Manager
    bspwm picom polybar rofi sxhkd xinput suckless-tools wmctrl jgmenu

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

    # Shell
    zsh zsh-syntax-highlighting zsh-autosuggestions

    # Archive tools
    zip unzip p7zip-full

    # Python utilities (polybar key-indicator module)
    python3-pynput

    # Qt/GTK theming
    qt5ct qt6ct

    # ThinkPad T450 / Intel Broadwell hardware support
    tlp tlp-rdw                  # ThinkPad power management (battery life, charging thresholds)
    thermald                     # Intel thermal daemon — prevents throttling
    intel-microcode              # CPU microcode updates (security + stability)
    xserver-xorg-video-intel     # Intel Broadwell GPU driver (modesetting fallback is fine but this adds TearFree)
    vainfo intel-media-va-driver # VA-API hardware video decode (H.264/H.265 via i965)
    firmware-misc-nonfree        # Miscellaneous firmware blobs

    # Performance / reliability daemons
    irqbalance                   # Spread NIC/USB interrupts across all 4 CPUs (default: all on CPU0)
    earlyoom                     # Kill runaway processes fast before kernel OOM thrash-kills the wrong one
    systemd-zram-generator       # 2GB zstd compressed RAM swap buffer — absorbs bursts before touching SSD
  )

  log "Updating package list..."
  sudo apt update || error_exit "Failed to update packages"

  log "Installing required packages..."
  if sudo apt install -y "${required_packages[@]}"; then
    log "Package installation completed!"
  else
    log_warn "Some packages may have failed; continuing."
  fi

  # Set zsh as default shell for the current user
  if command -v zsh &>/dev/null; then
    local zsh_path
    zsh_path=$(command -v zsh)
    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
      log "Setting zsh as default shell for $USER..."
      sudo chsh -s "$zsh_path" "$USER" || log_warn "Could not set zsh as default shell"
    else
      log "zsh already the default shell"
    fi
  fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_root
  install_packages
fi
