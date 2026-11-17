#!/bin/bash
TARGET_FILE="$HOME/.current_target"
ZSHRC_FILE="$HOME/.zshrc"

rofi_theme(){
  rofi -theme "$HOME/.config/rofi/target.rasi" "$@"
}


# Function to set global variables in zshrc
setg_zshrc() {
  if [ $# -ne 2 ]; then
    echo "Usage: setg_zshrc <variable> <value>"
    return 1
  fi

  local var_name="${1,,}"  # Convert to lowercase
  local var_value="$2"
  local zshrc_actual=$(readlink -f "$ZSHRC_FILE")
  local temp_file=$(mktemp)
  local var_exists=0
  
  # Update variable if it exists, otherwise keep line as is
  while IFS= read -r line; do
    if [[ "$line" =~ ^export\ ${var_name}= ]]; then
      echo "export ${var_name}=\"$var_value\"" >> "$temp_file"
      var_exists=1
    else
      echo "$line" >> "$temp_file"
    fi
  done < "$zshrc_actual"
  
  # Add variable if it doesn't exist
  if [[ $var_exists -eq 0 ]]; then
    echo "export ${var_name}=\"$var_value\"" >> "$temp_file"
  fi
  
  # Replace original file and update target file
  cat "$temp_file" > "$zshrc_actual"
  rm "$temp_file"
  
  # Update current target file for rhost
  if [[ $var_name == "rhost" ]]; then
    echo "$var_value" > "$TARGET_FILE"
  fi
  
  echo "Global variable ${var_name} set to $var_value"
}

# Function to unset global variables in zshrc
unsetg_zshrc() {
  if [ $# -ne 1 ]; then
    echo "Usage: unsetg_zshrc <variable>"
    return 1
  fi

  local var_name="${1,,}"  # Convert to lowercase
  local zshrc_actual=$(readlink -f "$ZSHRC_FILE")
  local temp_file=$(mktemp)
  
  # Keep all lines except the one with our variable
  while IFS= read -r line; do
    if [[ ! "$line" =~ ^export\ ${var_name}= ]]; then
      echo "$line" >> "$temp_file"
    fi
  done < "$zshrc_actual"
  
  # Replace original file
  cat "$temp_file" > "$zshrc_actual"
  rm "$temp_file"
  
  # Special handling for rhost
  if [[ $var_name == "rhost" ]]; then
    echo "none" > "$TARGET_FILE"
  fi
  
  echo "Removed variable \"${var_name}\""
}

# Validate IPv4 address
validate_ip() {
  local ip=$1
  if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    # Check each octet
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
      if (( octet > 255 )); then
        return 1
      fi
    done
    return 0
  else
    return 1
  fi
}

# Inline editor: a small rofi box dropped right under the clicked module
# (x from the mouse position), prefilled, no messages. Prints the text typed;
# returns 1 on Esc.  inline_edit ICON PREFILL PLACEHOLDER [ERROR] < suggestions
inline_edit() {
  local icon=$1 prefill=$2 placeholder=$3 err=$4 x lines
  x=$(xdotool getmouselocation --shell 2>/dev/null | sed -n 's/^X=//p')
  x=$(( ${x:-1200} - 30 )); (( x < 0 )) && x=0
  (( x > 1350 )) && x=1350
  local input; input=$(cat)
  lines=$(printf '%s' "$input" | grep -c .)
  local ts="window { x-offset: ${x}px; } listview { lines: ${lines}; } entry { placeholder: \"${placeholder}\"; }"
  [[ -n $err ]] && ts+=" entry { text-color: #e5383b; } window { border-color: #e5383b; }"
  printf '%s' "$input" | rofi -dmenu -i -theme "$HOME/.config/rofi/inline.rasi" \
    -p "$icon" -filter "$prefill" -theme-str "$ts"
}

# Left click: edit the target inline (right click copies). Enter = save · empty Enter = clear ·
# Esc = cancel · an invalid IP turns the box red and stays open.
handle_edit() {
  local current prefill val err=
  current=$(cat "$TARGET_FILE" 2>/dev/null)
  [[ $current == none ]] && current=
  prefill=$current
  while true; do
    val=$(printf '' | inline_edit $'\U000f04fe' "$prefill" "target ip" "$err") || exit 0
    val=$(echo "$val" | tr -d '[:space:]')
    if [[ -z $val || $val == clear ]]; then
      [[ -n $current ]] && { unsetg_zshrc rhost >/dev/null; notify-send -u low "RHOST cleared"; }
      exit 0
    fi
    if validate_ip "$val"; then
      setg_zshrc rhost "$val" >/dev/null
      notify-send -u low "RHOST $val"
      exit 0
    fi
    prefill=$val err=1
  done
}

case "$1" in
  "--copy")
    if [ -f "$TARGET_FILE" ] && [ "$(cat "$TARGET_FILE")" != "none" ]; then
      cat "$TARGET_FILE" | tr -d "\n" | xclip -sel clip
      notify-send -u low "Target copied to clipboard: $(cat "$TARGET_FILE")"
      echo "Target copied"
    else
      # nothing to copy yet: open the inline editor instead
      handle_edit
    fi
    ;;
  "--edit")
    handle_edit
    ;;
  --bar)
    # polybar: value only (the bar adds the icon); grey "none" when unset
    t=$(cat "$TARGET_FILE" 2>/dev/null)
    if [ -n "$t" ] && [ "$t" != "none" ]; then echo "$t"; else echo "%{F#4b4d55}none%{F-}"; fi
    ;;
  *)
    if [ -f "$TARGET_FILE" ]; then
      echo "R:$(cat "$TARGET_FILE")"
    else
      echo "R:none"
    fi
    ;;
esac
