#!/bin/bash

# Font Configuration Script
# Changes system font to AdwaitaMono Nerd Font Mono across all applications
# Author: Generated for system-wide font changes
# Date: 2026-01-24

set -e

# Configuration
FONT_NAME="AdwaitaMono Nerd Font Mono"
FONT_SIZE="11"

echo "=========================================="
echo "Font Configuration Script"
echo "=========================================="
echo "Font: $FONT_NAME"
echo "Size: $FONT_SIZE"
echo ""

# ==========================================
# 1. GTK 2 Configuration
# ==========================================
echo "[1/6] Configuring GTK 2..."
cat > ~/.gtkrc-2.0 << EOF
gtk-font-name="$FONT_NAME $FONT_SIZE"
EOF
echo "✓ GTK 2 configured"

# ==========================================
# 2. GTK 3 Configuration
# ==========================================
echo "[2/6] Configuring GTK 3..."
mkdir -p ~/.config/gtk-3.0

# Read existing settings if they exist
if [ -f ~/.config/gtk-3.0/settings.ini ]; then
    # Remove old font-name line if it exists
    sed -i '/^gtk-font-name=/d' ~/.config/gtk-3.0/settings.ini
fi

# Ensure [Settings] section exists
if ! grep -q "^\[Settings\]" ~/.config/gtk-3.0/settings.ini 2>/dev/null; then
    echo "[Settings]" > ~/.config/gtk-3.0/settings.ini
fi

# Add font configuration after [Settings]
sed -i '/^\[Settings\]/a gtk-font-name='"$FONT_NAME $FONT_SIZE" ~/.config/gtk-3.0/settings.ini
echo "✓ GTK 3 configured"

# ==========================================
# 3. GTK 4 Configuration
# ==========================================
echo "[3/6] Configuring GTK 4..."
mkdir -p ~/.config/gtk-4.0

# Read existing settings if they exist
if [ -f ~/.config/gtk-4.0/settings.ini ]; then
    # Remove old font-name line if it exists
    sed -i '/^gtk-font-name=/d' ~/.config/gtk-4.0/settings.ini
fi

# Ensure [Settings] section exists
if ! grep -q "^\[Settings\]" ~/.config/gtk-4.0/settings.ini 2>/dev/null; then
    echo "[Settings]" > ~/.config/gtk-4.0/settings.ini
fi

# Add font configuration after [Settings]
sed -i '/^\[Settings\]/a gtk-font-name='"$FONT_NAME $FONT_SIZE" ~/.config/gtk-4.0/settings.ini
echo "✓ GTK 4 configured"

# ==========================================
# 4. X Resources Configuration
# ==========================================
echo "[4/6] Configuring X Resources..."

# Note: .Xresources is a symlink, so we need to update the actual file
XRESOURCES_PATH=$(readlink -f ~/.Xresources)

if [ -f "$XRESOURCES_PATH" ]; then
    # Update XTerm and UXTerm font
    sed -i "s/^XTerm\*faceName:.*/XTerm*faceName: $FONT_NAME/" "$XRESOURCES_PATH"
    sed -i "s/^UXTerm\*faceName:.*/UXTerm*faceName: $FONT_NAME/" "$XRESOURCES_PATH"
    sed -i "s/^XTerm\*boldFont:.*/XTerm*boldFont: $FONT_NAME Bold/" "$XRESOURCES_PATH"
    sed -i "s/^UXTerm\*boldFont:.*/UXTerm*boldFont: $FONT_NAME Bold/" "$XRESOURCES_PATH"
    sed -i "s/^XTerm\*wideFont:.*/XTerm*wideFont: $FONT_NAME/" "$XRESOURCES_PATH"
    sed -i "s/^UXTerm\*wideFont:.*/UXTerm*wideFont: $FONT_NAME/" "$XRESOURCES_PATH"
    sed -i "s/^XTerm\*wideBoldFont:.*/XTerm*wideBoldFont: $FONT_NAME Bold/" "$XRESOURCES_PATH"
    sed -i "s/^UXTerm\*wideBoldFont:.*/UXTerm*wideBoldFont: $FONT_NAME Bold/" "$XRESOURCES_PATH"
    
    # Reload X resources
    xrdb -merge ~/.Xresources
    echo "✓ X Resources configured and reloaded"
else
    echo "⚠ .Xresources not found, skipping..."
fi

# ==========================================
# 5. Qt Configuration
# ==========================================
echo "[5/6] Configuring Qt applications..."

# Qt5
if [ -d ~/.config/qt5ct ]; then
    if [ -f ~/.config/qt5ct/qt5ct.conf ]; then
        sed -i "s/^fixed=.*/fixed=\"$FONT_NAME,$FONT_SIZE,-1,5,50,0,0,0,0,0\"/" ~/.config/qt5ct/qt5ct.conf
        sed -i "s/^general=.*/general=\"$FONT_NAME,$FONT_SIZE,-1,5,50,0,0,0,0,0\"/" ~/.config/qt5ct/qt5ct.conf
    else
        mkdir -p ~/.config/qt5ct
        cat > ~/.config/qt5ct/qt5ct.conf << EOF
[Fonts]
fixed="$FONT_NAME,$FONT_SIZE,-1,5,50,0,0,0,0,0"
general="$FONT_NAME,$FONT_SIZE,-1,5,50,0,0,0,0,0"
EOF
    fi
    echo "✓ Qt5 configured"
else
    echo "⚠ Qt5ct not found, skipping..."
fi

# Qt6
if [ -d ~/.config/qt6ct ]; then
    if [ -f ~/.config/qt6ct/qt6ct.conf ]; then
        sed -i "s/^fixed=.*/fixed=\"$FONT_NAME,$FONT_SIZE,-1,5,50,0,0,0,0,0\"/" ~/.config/qt6ct/qt6ct.conf
        sed -i "s/^general=.*/general=\"$FONT_NAME,$FONT_SIZE,-1,5,50,0,0,0,0,0\"/" ~/.config/qt6ct/qt6ct.conf
    else
        mkdir -p ~/.config/qt6ct
        cat > ~/.config/qt6ct/qt6ct.conf << EOF
[Fonts]
fixed="$FONT_NAME,$FONT_SIZE,-1,5,50,0,0,0,0,0"
general="$FONT_NAME,$FONT_SIZE,-1,5,50,0,0,0,0,0"
EOF
    fi
    echo "✓ Qt6 configured"
else
    echo "⚠ Qt6ct not found, skipping..."
fi

# ==========================================
# 6. Fontconfig Configuration
# ==========================================
echo "[6/6] Configuring fontconfig..."
mkdir -p ~/.config/fontconfig

cat > ~/.config/fontconfig/fonts.conf << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- Default monospace font -->
  <alias>
    <family>monospace</family>
    <prefer>
      <family>AdwaitaMono Nerd Font Mono</family>
    </prefer>
  </alias>
  
  <!-- Default sans-serif font (you can change this too) -->
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>AdwaitaMono Nerd Font Mono</family>
    </prefer>
  </alias>
  
  <!-- Default serif font (you can change this too) -->
  <alias>
    <family>serif</family>
    <prefer>
      <family>AdwaitaMono Nerd Font Mono</family>
    </prefer>
  </alias>
  
  <!-- Font rendering settings -->
  <match target="font">
    <edit name="antialias" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="hinting" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="hintstyle" mode="assign">
      <const>hintslight</const>
    </edit>
    <edit name="rgba" mode="assign">
      <const>rgb</const>
    </edit>
    <edit name="lcdfilter" mode="assign">
      <const>lcddefault</const>
    </edit>
  </match>
</fontconfig>
EOF

# Rebuild font cache
fc-cache -fv > /dev/null 2>&1
echo "✓ Fontconfig configured and cache rebuilt"

# ==========================================
# Summary
# ==========================================
echo ""
echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "The following files have been updated:"
echo "  • ~/.gtkrc-2.0"
echo "  • ~/.config/gtk-3.0/settings.ini"
echo "  • ~/.config/gtk-4.0/settings.ini"
echo "  • ~/.Xresources (via symlink)"
echo "  • ~/.config/qt5ct/qt5ct.conf"
echo "  • ~/.config/qt6ct/qt6ct.conf"
echo "  • ~/.config/fontconfig/fonts.conf"
echo ""
echo "IMPORTANT: To apply changes:"
echo "  1. Log out and log back in (recommended)"
echo "  2. Or restart individual applications"
echo "  3. For Qt apps, ensure QT_QPA_PLATFORMTHEME=qt5ct"
echo ""
echo "To verify the font is installed:"
echo "  fc-list | grep -i adwaita"
echo ""
