#!/usr/bin/env bash
# font.sh — Global interface font switcher TUI
# Updates font across all configured applications (terminals, bars, menus, GTK, Qt, etc.)
# Polybar icon/symbol fonts (Symbols Nerd Font Mono) are always preserved.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$SCRIPT_DIR/../dot"

# ── ANSI ─────────────────────────────────────────────────────────────────────
R='\033[0;31m'  G='\033[0;32m'  Y='\033[0;33m'  C='\033[0;36m'
W='\033[0;37m'  B='\033[1m'     D='\033[2m'      N='\033[0m'

die()  { echo -e "${R}error:${N} $*" >&2; exit 1; }
ok()   { echo -e "  ${G}✓${N}  $*"; }
skip() { echo -e "  ${D}·  $* (not found)${N}"; }

header() {
    clear
    echo -e "${B}${C}"
    cat << 'EOF'
  ┌─────────────────────────────────┐
  │       font configuration        │
  └─────────────────────────────────┘
EOF
    echo -e "${N}"
}

# ── Dependencies ──────────────────────────────────────────────────────────────
check_deps() {
    local missing=()
    for cmd in fzf fc-list sed; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    [[ ${#missing[@]} -eq 0 ]] || die "missing: ${missing[*]}"
}

# ── Current state ─────────────────────────────────────────────────────────────
current_font() {
    local cfg="$DOTS_DIR/.config/polybar/config.ini"
    [[ -f "$cfg" ]] || { echo "Unknown"; return; }
    sed -n 's|^font-0 = "\([^:]*\):.*|\1|p' "$cfg" | head -1
}

current_size() {
    local cfg="$DOTS_DIR/.config/polybar/config.ini"
    [[ -f "$cfg" ]] || { echo "11"; return; }
    sed -n 's|.*pixelsize=\([0-9]*\).*|\1|p' "$cfg" | head -1
}

# ── Font discovery ────────────────────────────────────────────────────────────
list_nerd_fonts() {
    fc-list --format="%{family}\n" \
        | tr ',' '\n' \
        | sed 's/^ *//;s/ *$//' \
        | grep -i "nerd font" \
        | grep -iv "symbols" \
        | sort -u
}

# ── TUI: font picker ──────────────────────────────────────────────────────────
pick_font() {
    local cur="$1"
    local fonts
    fonts=$(list_nerd_fonts) || true
    [[ -n "$fonts" ]] || die "no Nerd Fonts installed — run install/fonts.sh first"

    echo -e "  ${D}current font: ${W}$cur${N}"
    echo -e "  ${D}↑↓ navigate  Enter select  Esc cancel${N}\n"

    fzf \
        --prompt="  font › " \
        --header="Select interface font (symbol/icon fonts are preserved)" \
        --height=50% \
        --border=rounded \
        --color="header:italic,prompt:bold,border:238" \
        --no-info \
        <<< "$fonts"
}

# ── TUI: size picker ──────────────────────────────────────────────────────────
pick_size() {
    local cur="$1"
    echo -e "  ${D}current size: ${W}$cur${N}"
    echo -e "  ${D}↑↓ navigate  Enter select  Esc cancel${N}\n"

    printf '%s\n' 8 9 10 11 12 13 14 15 16 | fzf \
        --prompt="  size › " \
        --header="Select font size (applied globally)" \
        --height=40% \
        --border=rounded \
        --color="header:italic,prompt:bold,border:238" \
        --no-info \
        --query="$cur"
}

# ── Sed escape: escapes \ | & for use in sed replacement strings ─────────────
sed_esc() { printf '%s' "$1" | sed 's/[\\|&]/\\&/g'; }

# ── Patch helper ──────────────────────────────────────────────────────────────
patch() {
    local file="$1" expr="$2" label="$3"
    [[ -f "$file" ]] || { skip "$label"; return; }
    sed -i "$expr" "$file"
    ok "$label"
}

patch2() {
    local file="$1" e1="$2" e2="$3" label="$4"
    [[ -f "$file" ]] || { skip "$label"; return; }
    sed -i "$e1" "$file"
    sed -i "$e2" "$file"
    ok "$label"
}

# ── Apply to dotfiles ─────────────────────────────────────────────────────────
apply_dotfiles() {
    local font="$1" size="$2" d="$DOTS_DIR"
    local ef; ef=$(sed_esc "$font")

    echo -e "\n  ${B}dotfiles${N}"
    echo -e "  ────────────────────────────────\n"

    # kitty — font_size + family entries inside BEGIN/END_KITTY_FONTS
    local kitty="$d/.config/kitty/kitty.conf"
    if [[ -f "$kitty" ]]; then
        sed -i 's|^font_size .*|font_size '"$size"'|' "$kitty"
        sed -i '/# BEGIN_KITTY_FONTS/,/# END_KITTY_FONTS/ s|family="[^"]*"|family="'"$ef"'"|' "$kitty"
        ok "kitty"
    else
        skip "kitty"
    fi

    # alacritty — size + family fields
    local alacritty="$d/.config/alacritty/alacritty.toml"
    if [[ -f "$alacritty" ]]; then
        sed -i 's|^size = .*|size = '"$size"'|' "$alacritty"
        sed -i 's|^family = ".*"|family = "'"$ef"'"|' "$alacritty"
        ok "alacritty"
    else
        skip "alacritty"
    fi

    # polybar — font-0 only; symbol fonts (font-1 through font-9) untouched
    local polybar="$d/.config/polybar/config.ini"
    if [[ -f "$polybar" ]]; then
        sed -i 's|^font-0 = .*|font-0 = "'"$ef"':pixelsize='"$size"':style=Regular:antialias=true;3"|' "$polybar"
        ok "polybar  ${D}(font-0; symbols preserved)${N}"
    else
        skip "polybar"
    fi

    # rofi — shared font (imported by launch / pwmenu / window)
    patch "$d/.config/rofi/shared/fonts.rasi" \
        's|font: "[^"]*";|font: "'"$ef Regular $size"'";|' \
        "rofi/shared/fonts.rasi"

    # rofi window.rasi — inline label override
    patch "$d/.config/rofi/window.rasi" \
        's|font: *"[^"]*";|font:                     "'"$ef Regular $size"'";|' \
        "rofi/window.rasi"

    # rofi calendar.rasi
    patch "$d/.config/rofi/calendar.rasi" \
        's|font: "[^"]*";|font: "'"$ef Regular $size"'";|' \
        "rofi/calendar.rasi"

    # rofi pentest-input.rasi
    patch "$d/.config/rofi/shared/pentest-input.rasi" \
        's|font: *"[^"]*";|font:           "'"$ef Regular $size"'";|' \
        "rofi/shared/pentest-input.rasi"

    # dunst
    patch "$d/.config/dunst/dunstrc" \
        's|^\( *\)font = .*|\1font = '"$ef Regular $size"'|' \
        "dunst"

    # jgmenu
    patch "$d/.config/jgmenu/jgmenurc" \
        's|^font = .*|font = '"$ef Bold $size"'|' \
        "jgmenu"

    # gtk2
    patch "$d/.gtkrc-2.0" \
        's|^gtk-font-name=.*|gtk-font-name="'"$ef $size"'"|' \
        "gtk2"

    # gtk3
    patch "$d/.config/gtk-3.0/settings.ini" \
        's|^gtk-font-name=.*|gtk-font-name='"$ef Regular $size"'|' \
        "gtk3"

    # gtk4
    patch "$d/.config/gtk-4.0/settings.ini" \
        's|^gtk-font-name=.*|gtk-font-name='"$ef Regular $size"'|' \
        "gtk4"

    # qt5ct
    patch2 "$d/.config/qt5ct/qt5ct.conf" \
        's|^fixed=.*|fixed="'"$ef,$size"',-1,5,400,0,0,0,0,0"|' \
        's|^general=.*|general="'"$ef,$size"',-1,5,400,0,0,0,0,0"|' \
        "qt5ct"

    # qt6ct
    patch2 "$d/.config/qt6ct/qt6ct.conf" \
        's|^fixed=.*|fixed="'"$ef,$size"',-1,5,400,0,0,0,0,0,0,0,0,0,0,1"|' \
        's|^general=.*|general="'"$ef,$size"',-1,5,400,0,0,0,0,0,0,0,0,0,0,1"|' \
        "qt6ct"

    # xresources
    local xres="$d/.Xresources"
    if [[ -f "$xres" ]]; then
        sed -i 's|^XTerm\*faceName:.*|XTerm*faceName: '"$ef"'|'        "$xres"
        sed -i 's|^UXTerm\*faceName:.*|UXTerm*faceName: '"$ef"'|'      "$xres"
        sed -i 's|^XTerm\*faceSize:.*|XTerm*faceSize: '"$size"'|'        "$xres"
        sed -i 's|^UXTerm\*faceSize:.*|UXTerm*faceSize: '"$size"'|'      "$xres"
        sed -i 's|^XTerm\*boldFont:.*|XTerm*boldFont: '"$ef Bold"'|'   "$xres"
        sed -i 's|^UXTerm\*boldFont:.*|UXTerm*boldFont: '"$ef Bold"'|' "$xres"
        sed -i 's|^XTerm\*wideFont:.*|XTerm*wideFont: '"$ef"'|'        "$xres"
        sed -i 's|^UXTerm\*wideFont:.*|UXTerm*wideFont: '"$ef"'|'      "$xres"
        sed -i 's|^XTerm\*wideBoldFont:.*|XTerm*wideBoldFont: '"$ef Bold"'|'   "$xres"
        sed -i 's|^UXTerm\*wideBoldFont:.*|UXTerm*wideBoldFont: '"$ef Bold"'|' "$xres"
        ok "xresources"
    else
        skip ".Xresources"
    fi

    # fontconfig — font inside each <prefer> block
    local fc="$d/.config/fontconfig/fonts.conf"
    if [[ -f "$fc" ]]; then
        sed -i '/<prefer>/,/<\/prefer>/ s|<family>[^<]*</family>|<family>'"$ef"'</family>|' "$fc"
        ok "fontconfig"
    else
        skip "fontconfig"
    fi
}

# ── Live reloads ──────────────────────────────────────────────────────────────
apply_live() {
    echo -e "\n  ${B}live system${N}"
    echo -e "  ────────────────────────────────\n"

    # xrdb
    if [[ -n "${DISPLAY:-}" ]] && command -v xrdb &>/dev/null && [[ -f "$HOME/.Xresources" ]]; then
        xrdb -merge "$HOME/.Xresources" 2>/dev/null && ok "xrdb reloaded" || true
    fi

    # polybar
    if pgrep -x polybar &>/dev/null && command -v polybar-msg &>/dev/null; then
        polybar-msg cmd restart &>/dev/null && ok "polybar restarted" || true
    fi

    # font cache
    fc-cache -f 2>/dev/null && ok "font cache rebuilt" || true
}

# ── Confirm ───────────────────────────────────────────────────────────────────
confirm() {
    local font="$1" size="$2" cur_font="$3" cur_size="$4"
    echo
    echo -e "  ${B}summary${N}"
    echo -e "  ────────────────────────────────"
    echo -e "  font  ${D}$cur_font${N}  →  ${G}${B}$font${N}"
    echo -e "  size  ${D}$cur_size${N}  →  ${G}${B}$size${N}"
    echo
    echo -e "  ${D}kitty · alacritty · polybar(font-0) · rofi"
    echo -e "  dunst · jgmenu · gtk2/3/4 · qt5/6 · xresources · fontconfig${N}"
    echo
    read -r -p "  apply? [Y/n] " ans
    [[ "${ans,,}" == n* ]] && return 1
    return 0
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    check_deps
    header

    local cur_font cur_size
    cur_font=$(current_font)
    cur_size=$(current_size)

    # pick font
    local font
    font=$(pick_font "$cur_font") || { echo -e "\n  ${Y}cancelled${N}\n"; exit 0; }

    header

    # pick size
    local size
    size=$(pick_size "$cur_size") || { echo -e "\n  ${Y}cancelled${N}\n"; exit 0; }

    header

    # confirm
    confirm "$font" "$size" "$cur_font" "$cur_size" || { echo -e "\n  ${Y}cancelled${N}\n"; exit 0; }

    header

    apply_dotfiles "$font" "$size"
    apply_live

    echo
    echo -e "  ${B}${G}done${N}  ${B}$font $size${N}"
    echo -e "  ${D}re-login for GTK/Qt changes to take full effect${N}"
    echo
}

main "$@"
