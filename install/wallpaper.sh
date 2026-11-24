#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Personal wallpaper: the BSPWN layout with the user name (whoami, capitals) in the middle.
# Written to ~/.local/share/bspwn/wallpaper.jpg; cockpit.conf and bspwm/start use it when it exists,
# otherwise the bundled assets/wallpaper/bspwn.jpg. Delete the file to go back to the BSPWN wordmark.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

install_wallpaper() {
  local root out
  root="$(get_project_root)"
  out="$HOME/.local/share/bspwn/wallpaper.jpg"
  if ! python3 -c 'import PIL' 2>/dev/null; then
    log_warn "python3-pil (Pillow) not found: keeping the bundled BSPWN wallpaper (sudo apt install python3-pil)"
    return 0
  fi
  mkdir -p "$(dirname "$out")"
  if python3 "$root/scripts/wallpaper/gen_bspwn.py" --user "$out" >/dev/null; then
    log "Personal wallpaper for $(whoami | tr '[:lower:]' '[:upper:]') written to $out"
  else
    log_warn "Could not generate the personal wallpaper; the bundled one stays in use"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  install_wallpaper
fi
