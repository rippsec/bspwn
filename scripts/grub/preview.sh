#!/bin/bash
# Boot the real GRUB (x86_64-efi) with the bspwn theme in a QEMU window.
# Nothing on the host's /boot is touched; menu entries are dummies.
#
# usage: scripts/grub/preview.sh [THEME_DIR] [--shot OUT.png]
#   --shot  headless: wait for the menu, save a screenshot, exit
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THEME="$ROOT/system/boot/grub/themes/bspwn"
SHOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --shot) SHOT="$(realpath -m "$2")"; shift ;;
    *) THEME="$(realpath "$1")" ;;
  esac
  shift
done

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/esp/EFI/BOOT"
cat > "$WORK/grub.cfg" <<'EOF'
insmod all_video
insmod gfxterm
insmod gfxmenu
insmod png
set gfxmode=1920x1080,auto
terminal_output gfxterm
EOF
for f in "$THEME"/*.pf2; do echo "loadfont \$prefix/themes/bspwn/${f##*/}"; done >> "$WORK/grub.cfg"
cat >> "$WORK/grub.cfg" <<'EOF'
set theme=$prefix/themes/bspwn/theme.txt
set timeout=30
menuentry "Kali GNU/Linux" { echo "preview only"; sleep 2; }
submenu "Advanced options for Kali GNU/Linux" {
  menuentry "Kali GNU/Linux, with Linux 7.2.15+kali-amd64" { true; }
  menuentry "Kali GNU/Linux, with Linux 7.2.15+kali-amd64 (recovery mode)" { true; }
}
menuentry "UEFI Firmware Settings" { fwsetup; }
EOF
grub-mkstandalone -O x86_64-efi -o "$WORK/esp/EFI/BOOT/BOOTX64.EFI" \
  --modules="part_gpt fat png gfxterm gfxmenu all_video font echo sleep" \
  "boot/grub/grub.cfg=$WORK/grub.cfg" "boot/grub/themes/bspwn=$THEME"

cp /usr/share/OVMF/OVMF_VARS_4M.fd "$WORK/vars.fd"
QEMU=(qemu-system-x86_64 -m 512 -machine q35 -no-reboot
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd
  -drive if=pflash,format=raw,file="$WORK/vars.fd"
  -drive file=fat:rw:"$WORK/esp",format=raw
  -device VGA,xres=1920,yres=1080 -net none)
[[ -r /dev/kvm ]] && QEMU+=(-enable-kvm)

if [[ -n "$SHOT" ]]; then
  "${QEMU[@]}" -display none -monitor unix:"$WORK/mon",server,nowait &
  pid=$!
  sleep 12
  echo "screendump $WORK/shot.ppm" | python3 -c '
import socket,sys,time
s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); time.sleep(.3)
s.sendall(sys.stdin.read().encode()+b"\n"); time.sleep(1.5)' "$WORK/mon"
  kill "$pid" 2>/dev/null || true
  python3 -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).save(sys.argv[2])' "$WORK/shot.ppm" "$SHOT"
  echo "screenshot: $SHOT"
else
  echo "QEMU window: arrows/enter/e/c work as in real GRUB; close the window to quit."
  "${QEMU[@]}" -display gtk,zoom-to-fit=on
fi
