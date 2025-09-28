#!/bin/bash
# myip.sh

# Get IP address using the shared configuration
get_ipaddr() {
    local CURRENT_IP_FILE="$HOME/.current_ip"
    
    # Check if there's a custom IP set
    if [[ -f "$CURRENT_IP_FILE" ]] && [[ -s "$CURRENT_IP_FILE" ]]; then
        local file_mode=$(head -n 1 "$CURRENT_IP_FILE" | cut -d':' -f1)
        local file_value=$(head -n 1 "$CURRENT_IP_FILE" | cut -d':' -f2)
        
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

# Copy IP to clipboard if --copy flag is provided
if [ "$1" = "--copy" ]; then
    ip_to_copy=$(get_ipaddr)
    if [ "$ip_to_copy" != "offline" ]; then
        echo -n "$ip_to_copy" | xclip -selection clipboard
        notify-send -u low "$ip_to_copy copied to clipboard"
        echo "IP address copied to clipboard"
        exit 0
    else
        echo "No IP address to copy (offline)"
        exit 1
    fi
fi

# Default behavior: just output the IP
echo "L:$(get_ipaddr)"
