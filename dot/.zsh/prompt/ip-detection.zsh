# IP detection. Sets REPLY (no subshell); get_ipaddr prints it.
# Priority: custom IP in ~/.current_ip > chosen interface > tun0/tun1/tap0 (VPN)
# > wlan/ethernet > lo. Only ONE external process (`ip`), the rest is pure zsh.
_ipaddr() {
    local f=$HOME/.current_ip line mode= val=
    if [[ -s $f ]]; then
        IFS= read -r line < $f
        mode=${line%%:*} val=${line#*:}
    fi
    if [[ $mode == custom ]]; then REPLY=$val; return 0; fi

    local -A addr
    local l
    local -a w
    for l in ${(f)"$(ip -4 -o addr show 2>/dev/null)"}; do
        w=(${=l})                       # "3: wlan0 inet 192.168.1.5/24 ..."
        [[ -z ${addr[${w[2]}]} ]] && addr[${w[2]}]=${w[4]%%/*}
    done
    if [[ $mode == interface && -n ${addr[$val]} ]]; then REPLY=${addr[$val]}; return 0; fi
    local iface
    for iface in tun0 tun1 tap0 wlp3s0 wlan0 enp0s25 eth0 lo; do
        if [[ -n ${addr[$iface]} ]]; then REPLY=${addr[$iface]}; return 0; fi
    done
    REPLY=offline
}

get_ipaddr() {
    local REPLY
    _ipaddr
    print -r -- $REPLY
}

# Prompt helper: refresh the IP at most every 5 s (plus whenever ~/.current_ip
# changes), so most prompts don't spawn any process at all.
zmodload -F zsh/datetime p:EPOCHSECONDS 2>/dev/null
zmodload -F zsh/stat b:zstat 2>/dev/null
typeset -g _IP_CACHE= _IP_CACHE_T=0 _IP_CACHE_M=
_ipaddr_cached() {
    local m= ; local -a st
    [[ -e $HOME/.current_ip ]] && zstat -A st +mtime $HOME/.current_ip 2>/dev/null && m=$st[1]
    # NB: no `local REPLY` here — zsh locals are function-wide, it would hide
    # the caller's REPLY and the prompt would get an empty IP.
    if (( EPOCHSECONDS - _IP_CACHE_T >= 5 )) || [[ $m != $_IP_CACHE_M ]]; then
        _ipaddr
        _IP_CACHE=$REPLY _IP_CACHE_T=$EPOCHSECONDS _IP_CACHE_M=$m
    fi
    REPLY=$_IP_CACHE
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
