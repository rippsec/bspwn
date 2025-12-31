#!/usr/bin/env zsh

# === Configuration Variable Management ===

# Function to display current variables
show_options() {
  local allowed=("lhost" "lport" "rhost" "rport" "ssl" "proto")
  echo "┌── Current Configuration Options ──"
  for var in "${allowed[@]}"; do
    if [[ -v $var ]]; then
      printf "│ [1;36m%-6s[0m ▸ %s
" "$var" "${(P)var}"
    else
      printf "│ [1;31m%-6s[0m ▸ %s
" "$var" "(not set)"
    fi
  done
  echo "└───────────────────────────────────"
}

# Set global pentest variables (like Metasploit's setg)
setg() {
    if [ $# -eq 0 ]; then
        echo "Usage: setg <variable> [value]"
        return 1
    fi

    # Define allowed variables
    local allowed=("lhost" "lport" "rport" "rhost" "ssl" "proto")
    local var_name="${1:l}"  # Convert input to lowercase

    # Check if variable is allowed
    if [[ ! " ${allowed[@]} " =~ " ${var_name} " ]]; then
        echo "Error: '${var_name}' is not a configurable variable"
        echo "Allowed variables: ${allowed[@]}"
        return 1
    fi

    local var_value
    
    # Special handling for lhost variable
    if [[ $var_name == "lhost" ]]; then
        if [ $# -eq 1 ]; then
            # No value provided, use auto mode
            update_ip_config "auto"
            var_value=$(get_ipaddr)
            echo "Using auto-detected IP: $var_value"
        elif [[ "$2" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            # If it's a valid IPv4 address format, use custom mode
            update_ip_config "custom" "$2"
            var_value="$2"
        else
            # Try to get IP from specified interface
            if update_ip_config "interface" "$2"; then
                var_value=$(get_ipaddr)
                echo "Using IP from interface $2: $var_value"
            else
                # Fall back to auto mode
                update_ip_config "auto"
                var_value=$(get_ipaddr)
                echo "Falling back to auto-detected IP: $var_value"
            fi
        fi
    # Special handling for rhost
    elif [[ $var_name == "rhost" ]]; then
        if [ $# -ne 2 ]; then
            echo "Error: rhost requires an IP address value"
            return 1
        elif [[ "$2" != "none" ]] && ! [[ "$2" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "Error: Invalid IP address format for rhost"
            return 1
        else
            var_value="$2"
        fi
    # Handle other variables
    else
        if [ $# -ne 2 ]; then
            echo "Error: $var_name requires a value"
            return 1
        fi
        var_value="$2"
    fi

    # Get the actual file path (resolving symlink)
    local zshrc_actual=$(readlink -f ~/.zshrc)

    # Create a temporary file
    local temp_file=$(mktemp)

    # Check if the variable already exists in the file
    local var_exists=0

    # Process the file line by line and update the variable if it exists
    while IFS= read -r line; do
        if [[ "$line" =~ ^export\ ${var_name}= ]]; then
            # Special case for lhost - make it dynamic when in auto or interface mode
            if [[ $var_name == "lhost" && (! -f "$HOME/.current_ip" || $(head -n 1 "$HOME/.current_ip" | cut -d':' -f1) != "custom") ]]; then
                echo "export ${var_name}=\"\$(get_ipaddr)\"" >> "$temp_file"
            else
                echo "export ${var_name}=\"$var_value\"" >> "$temp_file"
            fi
            var_exists=1
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$zshrc_actual"

    # If the variable doesn't exist, append it to the end of the file
    if [[ $var_exists -eq 0 ]]; then
        # Special case for lhost - make it dynamic when in auto or interface mode
        if [[ $var_name == "lhost" && (! -f "$HOME/.current_ip" || $(head -n 1 "$HOME/.current_ip" | cut -d':' -f1) != "custom") ]]; then
            echo "export ${var_name}=\"\$(get_ipaddr)\"" >> "$temp_file"
        else
            echo "export ${var_name}=\"$var_value\"" >> "$temp_file"
        fi
    fi

    # Replace the original file with the new content
    cat "$temp_file" > "$zshrc_actual"
    rm "$temp_file"

    # Update current session
    export ${var_name}="$var_value"
    echo "Global variable ${var_name} set to $var_value"

    # Sync rhost to .current_target
    if [[ $var_name == "rhost" ]]; then
        echo "$var_value" > ~/.current_target
        echo "Updated ~/.current_target with rhost value"
    fi
}

# Unset/remove pentest variables
unsetg() {
    if [ $# -ne 1 ]; then
        echo "Usage: unsetg <variable>"
        return 1
    fi

    # Define allowed variables
    local allowed=("lhost" "lport" "rport" "rhost" "ssl" "proto")
    local var_name="${1:l}"  # Convert input to lowercase 

    # Check if variable is allowed
    if [[ ! " ${allowed[@]} " =~ " ${var_name} " ]]; then
        echo "Error: '${var_name}' is not a configurable variable"
        echo "Allowed variables: ${allowed[@]}"
        return 1
    fi

    # Get the actual file path (resolving symlink)
    local zshrc_actual=$(readlink -f ~/.zshrc)

    # Create a temporary file
    local temp_file=$(mktemp)

    # Process the file line by line, skipping the target variable
    while IFS= read -r line; do
        if [[ ! "$line" =~ ^export\ ${var_name}= ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$zshrc_actual"

    # Replace the original file with the new content
    cat "$temp_file" > "$zshrc_actual"
    rm "$temp_file"

    # Unset variable in the current session
    unset "$var_name"
    echo "[+] Removed variable \"${var_name}\""

    # Special handling for variables
    if [[ $var_name == "rhost" ]]; then
        echo "none" > ~/.current_target
        echo "Cleared ~/.current_target"
    elif [[ $var_name == "lhost" ]]; then
        # Reset IP configuration to auto mode
        echo "auto:" > "$HOME/.current_ip"
        echo "Reset IP configuration to auto mode"
    fi
    return 0
}

# Clear all pentest variables
function clear_all(){
    for i in "lhost" "lport" "rhost" "rport" "ssl" "proto"; do
        unsetg "$i";
    done
}

# === Security Functions ===

function mac(){
    find /sys/class/net -mindepth 1 -maxdepth 1 ! -name lo -printf "%P: " -execdir cat {}/address \; \
        | sort -n -r \
        | awk '{printf "[01;32m%s[0m - [01;31m%s[0m
",$1,$2 }'
}

function macc(){
    sudo ifconfig $1 down
    sudo macchanger -A $1
    sudo ifconfig $1 up
}

function rmk() {
    for item in "$@"; do
        if [[ -d "$item" ]]; then
            # If the item is a directory, remove it and all its contents securely
            find "$item" -type f -exec scrub -p dod {} \; -exec shred -zvun 9 -v {} \;
            find "$item" -depth -type d -exec rmdir {} \;
            if [[ $? -eq 0 ]]; then
                echo "Directory $item and its contents have been securely removed."
            else
                echo "Failed to remove directory $item or some of its contents."
            fi
        elif [[ -f "$item" ]]; then
            # If the item is a file, use the existing method
            scrub -p dod "$item"
            shred -zvun 9 -v "$item"
        else
            echo "Item $item does not exist or is neither a file nor a directory."
        fi
    done
}

function get_resolution() {
    xrandr | grep '*' | awk '{print $1}'
}

function lock_screen() {
    local resolution=$(get_resolution)
    convert ~/.config/i3lock/stop.png -gravity center -background black -extent "$resolution" ~/.config/i3lock/centered_stop.png
    i3lock -c 000000 -i ~/.config/i3lock/centered_stop.png
}
