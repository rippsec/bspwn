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

handle_edit() {
  current_target=$(cat "$TARGET_FILE" 2>/dev/null || echo "none")
  local message="Enter a valid IPv4 address"
  local prompt
  local initial_text
  local invalid_attempt=false
  local last_invalid_ip

  while true; do
    # Determine initial text and prompt based on state
    if $invalid_attempt; then
      message="Invalid IP! Enter a valid IPv4 address"
      prompt="[+] Set target IP"
      initial_text="$last_invalid_ip"
      invalid_attempt=false  # Reset for next iteration
    elif [ -n "$last_action" ]; then
      initial_text="$last_action"
      prompt="[+] Set target IP"
    else
      if [ "$current_target" = "none" ]; then
        message="[+] Set target IP"
        initial_text=""
      else
        message="Current $current_target"
        initial_text="$current_target"
      fi
    fi

    # Present Rofi dialog
    action=$(printf "clear" | rofi_theme -dmenu -p "$prompt" -mesg "$message" -selected-row 1)

    # Exit if user cancels
    [ -z "$action" ] && exit 0

    if [ "$action" = "clear" ]; then
      unsetg_zshrc rhost
      notify-send -u low "Target cleared"
      exit 0
    fi

    # Validate IP and handle result
    if validate_ip "$action"; then
      setg_zshrc rhost "$action"
      notify-send -u low "Target set to $action"
      exit 0
    else
      invalid_attempt=true
      last_invalid_ip="$action"
    fi
  done
}

case "$1" in
  "--copy")
    if [ -f "$TARGET_FILE" ] && [ "$(cat "$TARGET_FILE")" != "none" ]; then
      cat "$TARGET_FILE" | tr -d "\n" | xclip -sel clip
      notify-send -u low "Target copied to clipboard: $(cat "$TARGET_FILE")"
      echo "Target copied"
    else
      echo "No target"
      exit 1
    fi
    ;;
  "--edit")
    handle_edit
    ;;
  *)
    if [ -f "$TARGET_FILE" ]; then
      echo "R:$(cat "$TARGET_FILE")"
    else
      echo "R:none"
    fi
    ;;
esac
