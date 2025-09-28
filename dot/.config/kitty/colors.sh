#!/bin/bash
# previewer.sh
# preview colors on the kitty terminal with backup/restore functionality

export TERMINAL=kitty

# Directory containing your .sh theme files
THEMES_DIR="$HOME/.config/kitty/colors/installs"
KITTY_CONFIG="$HOME/.config/kitty"
COLOR_CONF="$KITTY_CONFIG/colors.conf"
BACKUP_CONF="$KITTY_CONFIG/colors.conf.bak"

# Function to create backup
create_backup() {
    if [[ -f "$COLOR_CONF" ]]; then
        cp "$COLOR_CONF" "$BACKUP_CONF"
        sleep 0.5
        echo "Backup created: $BACKUP_CONF"
        return 0
    else
        echo "Warning: No existing colors.conf found to backup"
        return 1
    fi
}

# Function to restore backup
restore_backup() {
    if [[ -f "$BACKUP_CONF" ]]; then
        cat "$BACKUP_CONF" > "$COLOR_CONF"
        # Reload kitty config to apply restored colors
        if command -v kitty &> /dev/null; then
            kitty @ load-config --no-response 2>/dev/null || true
        fi
        echo "Original theme restored from backup"
        #rm -f "$BACKUP_CONF"  # Clean up backup file after restore
        return 0
    else
        echo "Error: Backup file not found"
        return 1
    fi
}

# Function to apply new theme
apply_theme() {
    local theme_file="$1"
    bash "$theme_file"
    # Reload kitty config to apply new colors
    if command -v kitty &> /dev/null; then
        kitty @ load-config --no-response 2>/dev/null || true
    fi
}

# Function to cleanup on exit (called when ESC or Ctrl+C is pressed)
cleanup_and_restore() {
    echo ""
    echo "Restoring original theme..."
    restore_backup
    exit 0
}

# Set up trap to handle Ctrl+C and other exit signals
trap cleanup_and_restore SIGINT SIGTERM

# ALWAYS create backup at start of each run
if ! create_backup; then
    echo "Error: Could not create backup, exiting"
    exit 1
fi

echo "Theme selector started. Your current theme is backed up."
echo "Press CTRL+C or ESC to exit and automatically restore original theme."
echo ""

# Use fzf to select a theme (with trimmed names)
selected_theme=$(find "$THEMES_DIR" -name '*.sh' | while IFS= read -r file; do
    name=$(basename "$file" .sh)
    printf "%s\t%s\n" "$name" "$file"
done | fzf \
    --with-nth=1 \
    --delimiter=$'\t' \
    --preview='bash {2} && kitty @ load-config --no-response 2>/dev/null || true' \
    --preview-window=right:50% \
    --bind="enter:accept" \
    --bind="esc:abort" \
    --header="↑↓ to navigate, ENTER to apply theme, ESC/Ctrl+C to restore original")

# Check if user made a selection (fzf returns non-zero exit code when cancelled)
if [[ $? -eq 0 && -n "$selected_theme" ]]; then
    # User selected a theme with ENTER
    theme_path=$(echo "$selected_theme" | cut -d$'\t' -f2)
    apply_theme "$theme_path"
    echo "Theme applied: $(basename "$theme_path" .sh)"
    # Remove backup since user actively selected a theme
    #rm -f "$BACKUP_CONF"
    #echo "Backup removed - new theme is now active"
else
    # User cancelled with ESC or Ctrl+C - restore original theme
    cleanup_and_restore
fi
