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

    # Screen lock, screenshots, media keys, helpers used by sxhkd/bspwm/polybar/xlock
    i3lock-color imagemagick maim playerctl jq bc
    xscreensaver unclutter vmtouch gsimplecal xfce4-notes xfce4-clipman
    conky-all alacritty gnome-keyring

    # Shell
    zsh zsh-syntax-highlighting zsh-autosuggestions

    # Archive tools
    zip unzip p7zip-full

    # Fonts (apt) — Nerd Fonts are handled by fonts.sh
    fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji
    fonts-liberation fonts-crosextra-caladea fonts-crosextra-carlito
    fonts-freefont-ttf fonts-ipafont-gothic fonts-wqy-zenhei
    fonts-tlwg-loma-otf fonts-unifont fontconfig

    # Python utilities (polybar key-indicator module)
    python3-pynput

    # Qt/GTK theming
    qt5ct qt6ct

    # Dell Precision 7780 / Intel Raptor Lake hardware support
    tlp tlp-rdw                  # Power management (battery life, charging thresholds via Dell BAT0 sysfs)
    thermald                     # Intel thermal daemon — prevents throttling
    intel-microcode              # CPU microcode updates (security + stability)
    vainfo intel-media-va-driver # VA-API hardware video decode (iHD driver, Gen12+)
    firmware-misc-nonfree        # Miscellaneous firmware blobs
    firmware-sof-signed          # Intel Sound Open Firmware (Raptor Lake HDA/DSP audio)
    firmware-iwlwifi             # Intel WiFi firmware

    # Performance / reliability daemons
    irqbalance                   # Spread NIC/USB interrupts across all CPUs (default: all on CPU0)
    earlyoom                     # Kill runaway processes fast before kernel OOM thrash-kills the wrong one
    systemd-zram-generator       # 2GB zstd compressed RAM swap buffer — absorbs bursts before touching SSD
  )

  # ttf-mscorefonts-installer (Arial, Comic Sans, ...) needs contrib/non-free and an EULA preseed
  echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" \
    | sudo debconf-set-selections 2>/dev/null || true
  required_packages+=(ttf-mscorefonts-installer)

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
