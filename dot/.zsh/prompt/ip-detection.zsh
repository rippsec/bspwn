# Enhanced IP detection logic
get_ipaddr() {
    local CURRENT_IP_FILE="$HOME/.current_ip"
    local custom_mode=false
  
    # Check for custom/interface mode
    if [[ -f "$CURRENT_IP_FILE" ]] && [[ -s "$CURRENT_IP_FILE" ]]; then
        local file_mode=$(head -n 1 "$CURRENT_IP_FILE" | cut -d':' -f1)
        local file_value=$(head -n 1 "$CURRENT_IP_FILE" | cut -d':' -f2)
        
        if [[ "$file_mode" == "custom" ]]; then
            echo "$file_value"
            return 0
        elif [[ "$file_mode" == "interface" ]]; then
            # Check specified interface
            local ipaddr=$(ip -4 addr show "$file_value" 2>/dev/null | grep -Po 'inet \K\d{1,3}(\.\d{1,3}){3}' | head -n1)
            if [[ -n "$ipaddr" ]]; then
                echo "$ipaddr"
                return 0
            fi
        fi
    fi

    # Auto-detect
    local interfaces=("tun0" "tun1" "tap0" "wlan0" "wlan1" "eth0" "eth1" "lo")
    for iface in "${interfaces[@]}"; do
        if ip link show "$iface" &>/dev/null; then
            local ipaddr=$(ip -4 addr show "$iface" 2>/dev/null | grep -Po 'inet \K\d{1,3}(\.\d{1,3}){3}' | head -n1)
            if [[ -n "$ipaddr" ]]; then
                echo "$ipaddr"
                return 0
            fi
        fi
    done
    
    echo "offline"
    return 0
}

# Function to update the current IP configuration file
update_ip_config() {
    local mode="$1"
    local value="$2"
    local CURRENT_IP_FILE="$HOME/.current_ip"
    
    case "$mode" in
        auto)
            echo "auto:" > "$CURRENT_IP_FILE"
            ;;
        interface)
            local ip=$(get_ipaddr --detect "$value")
            if [[ $? -eq 0 && -n "$ip" && "$ip" != "offline" ]]; then
                echo "interface:$value" > "$CURRENT_IP_FILE"
                echo "$ip" >> "$CURRENT_IP_FILE"
            else
                echo "Error: Interface $value doesn't exist or has no IPv4 address"
                return 1
            fi
            ;;
        custom)
            if [[ "$value" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "custom:$value" > "$CURRENT_IP_FILE"
            else
                echo "Error: Invalid IPv4 address format"
                return 1
            fi
            ;;
        *)
            echo "Error: Invalid mode. Use 'auto', 'interface', or 'custom'"
            return 1
            ;;
    esac
    
    return 0
}
