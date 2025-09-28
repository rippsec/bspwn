#!/bin/bash
# mylhost.sh - Interface for managing LHOST IP settings

# File paths
IP_CONFIG_FILE="$HOME/.current_ip"
ZSHRC_FILE="$HOME/.zshrc"

# Use the theme from the config
rofi_theme(){
  rofi -theme "$HOME/.config/rofi/lhost.rasi" "$@"
}

# Function to update IP configuration
update_ip_config() {
  local mode="$1"
  local value="$2"
  
  # Validate interface if in interface mode
  if [[ "$mode" == "interface" ]]; then
    if ! ip link show "$value" &>/dev/null; then
      echo "Interface $value does not exist"
      return 1
    fi
  fi
  
  echo "${mode}:${value}" > "$IP_CONFIG_FILE"
  return 0
}

# Get IP address based on current configuration
get_ipaddr() {
    # Check if there's a custom IP set
    if [[ -f "$IP_CONFIG_FILE" ]] && [[ -s "$IP_CONFIG_FILE" ]]; then
        local file_mode=$(head -n 1 "$IP_CONFIG_FILE" | cut -d':' -f1)
        local file_value=$(head -n 1 "$IP_CONFIG_FILE" | cut -d':' -f2)
        
        # If it's in custom mode, return the stored IP
        if [[ "$file_mode" == "custom" ]]; then
            echo "$file_value"
            return 0
        elif [[ "$file_mode" == "interface" ]]; then
            # Use specified interface
            local iface="$file_value"
            if ip link show "$iface" &>/dev/null; then
                local ipaddr=$(ip -4 addr show "$iface" 2>/dev/null | grep -Po 'inet \K\d{1,3}(\.\d{1,3}){3}' | head -n1)
                if [[ -n $ipaddr ]]; then
                    echo "$ipaddr"
                    return 0
                fi
            fi
            # If interface no longer exists or has no IP, fall through to auto mode
        fi
    fi
    
    # Auto mode - check interfaces in priority order
    local interfaces=("tun0" "tap0" "eth0" "wlan0" "wlan1" "wlan2" "lo")
    for iface in "${interfaces[@]}"; do
        if ip link show "$iface" &>/dev/null; then
            local ipaddr=$(ip -4 addr show "$iface" 2>/dev/null | grep -Po 'inet \K\d{1,3}(\.\d{1,3}){3}' | head -n1)
            if [[ -n $ipaddr ]]; then
                echo "$ipaddr"
                return 0
            fi
        fi
    done
    
    echo "offline"
    return 0
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

# Get the current mode and value of lhost
get_lhost_mode() {
  if [[ -f "$IP_CONFIG_FILE" ]] && [[ -s "$IP_CONFIG_FILE" ]]; then
    local file_content=$(head -n 1 "$IP_CONFIG_FILE")
    echo "$file_content"
  else
    echo "auto:"
  fi
}

# Function to get all available network interfaces with IPs
get_interfaces_with_ips() {
  local interfaces=()
  local interfaces_with_ips=""
  
  # Get all interfaces with IPv4 addresses
  while read -r iface ipaddr; do
    interfaces+=("$iface: $ipaddr")
  done < <(ip -4 -o addr show | awk '{print $2, $4}' | cut -d/ -f1 | sort | uniq)
  
  # Format them for rofi menu
  printf "%s\n" "${interfaces[@]}"
}

# Clear lhost by using unsetg function and resetting to auto
clear_lhost() {
  # This is a simplified version - in actual use, we'd source the unsetg function
  # For now, we'll just update the config file to auto mode
  update_ip_config "auto" ""
  
  # Get the actual file path (resolving symlink)
  local zshrc_actual=$(readlink -f "$ZSHRC_FILE")
  local temp_file=$(mktemp)
  
  # Process the file line by line, skipping the lhost variable
  while IFS= read -r line; do
    if [[ ! "$line" =~ ^export\ lhost= ]]; then
      echo "$line" >> "$temp_file"
    fi
  done < "$zshrc_actual"
  
  # Add dynamic lhost
  echo 'export lhost="$(get_ipaddr)"' >> "$temp_file"
  
  # Replace the original file with the new content
  cat "$temp_file" > "$zshrc_actual"
  rm "$temp_file"
  
  unset lhost
  notify-send -u low "LHOST reset to auto mode"
}

# Set lhost using the setg function logic
set_lhost() {
  local value="$1"
  local mode=""
  local ip_value=""
  
  # Check if it's an IP address or interface
  if validate_ip "$value"; then
    mode="custom"
    ip_value="$value"
  else
    # Check if it's a valid interface
    if ip link show "$value" &>/dev/null; then
      mode="interface"
      ip_value="$value"
    else
      echo "Invalid IP or interface: $value"
      return 1
    fi
  fi
  
  # Update config file
  update_ip_config "$mode" "$ip_value"
  
  # Get the actual IP to display
  local actual_ip=$(get_ipaddr)
  
  # Get the actual file path (resolving symlink)
  local zshrc_actual=$(readlink -f "$ZSHRC_FILE")
  local temp_file=$(mktemp)
  local var_exists=0
  
  # Process the file line by line and update the variable if it exists
  while IFS= read -r line; do
    if [[ "$line" =~ ^export\ lhost= ]]; then
      # If custom mode, set static value, otherwise make it dynamic
      if [[ "$mode" == "custom" ]]; then
        echo "export lhost=\"$ip_value\"" >> "$temp_file"
      else
        echo "export lhost=\"\$(get_ipaddr)\"" >> "$temp_file"
      fi
      var_exists=1
    else
      echo "$line" >> "$temp_file"
    fi
  done < "$zshrc_actual"
  
  # If the variable doesn't exist, append it to the end of the file
  if [[ $var_exists -eq 0 ]]; then
    if [[ "$mode" == "custom" ]]; then
      echo "export lhost=\"$ip_value\"" >> "$temp_file"
    else
      echo "export lhost=\"\$(get_ipaddr)\"" >> "$temp_file"
    fi
  fi
  
  # Replace the original file with the new content
  cat "$temp_file" > "$zshrc_actual"
  rm "$temp_file"
  
  # Update current session
  if [[ "$mode" == "custom" ]]; then
    export lhost="$ip_value"
  else
    export lhost="$actual_ip"
  fi
  
  notify-send -u low "LHOST set to $actual_ip (mode: $mode)"
}

# Handle Edit
handle_edit() {
  local current_ip=$(get_ipaddr)
  local current_mode=$(get_lhost_mode | cut -d':' -f1)
  local current_value=$(get_lhost_mode | cut -d':' -f2)
  local prompt="[+] LHOST:"
  local message=""
  local menu_options=""
  local invalid_attempt=false
  local last_invalid_input=""

  while true; do
    # Update message and prompt based on state
    if $invalid_attempt; then
      message="Invalid: '$last_invalid_input'. Current: $current_ip"
      prompt="[+] LHOST (Invalid):"
      invalid_attempt=false
    else
      if [[ "$current_mode" == "custom" ]]; then
        message="Current: $current_ip (custom)"
      elif [[ "$current_mode" == "interface" ]]; then
        message="Current: $current_ip ($current_value)"
      else
        message="Current: $current_ip (auto)"
      fi
      prompt="[+] LHOST:"
    fi

    # Generate menu options
    menu_options=$(get_interfaces_with_ips)
    menu_options="[!] Clear lhost (resets to default)\n${menu_options}"

    # Show Rofi dialog
    selected=$(echo -e "$menu_options" | rofi_theme -dmenu -p "$prompt" -mesg "$message" -selected-row 1)

    # Exit on cancel
    [ -z "$selected" ] && exit 0

    # Handle clear action
    if [[ "$selected" == "[!] Clear lhost (resets to default)" ]]; then
      clear_lhost
      exit 0
    fi

    # Process input
    if [[ "$selected" =~ ^[a-zA-Z0-9]+:\ .* ]]; then
      input_value=$(echo "$selected" | cut -d':' -f1)
    else
      input_value="$selected"
    fi

    # Validate and set LHOST
    if set_lhost "$input_value"; then
      exit 0
    else
      invalid_attempt=true
      last_invalid_input="$input_value"
      # Refresh current IP and mode after failed attempt
      current_ip=$(get_ipaddr)
      current_mode=$(get_lhost_mode | cut -d':' -f1)
      current_value=$(get_lhost_mode | cut -d':' -f2)
    fi
  done
}


# Handle copy mode
handle_copy() {
  local current_ip=$(get_ipaddr)
  if [[ "$current_ip" != "offline" ]]; then
    echo -n "$current_ip" | xclip -selection clipboard
    notify-send -u low "LHOST $current_ip copied to clipboard"
    echo "IP address copied to clipboard"
    exit 0
  else
    echo "No IP address to copy (offline)"
    exit 1
  fi
}

# Main script logic
case "$1" in
  "--copy")
    handle_copy
    ;;
  "--edit")
    handle_edit
    ;;
  *)
    echo "L:$(get_ipaddr)"
    ;;
esac
