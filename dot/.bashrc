# ~/.bashrc

# --- Guard: non-interactive shells ---
case $- in
    *i*) ;;
    *) return ;;
esac

# ==============================================================
# COLORS
# ==============================================================
red="\e[0;31m\033[1m"
green="\e[0;32m\033[1m"
yellow="\e[0;33m\033[1m"
blue="\e[0;34m\033[1m"
purple="\e[0;35m\033[1m"
cyan="\e[0;36m\033[1m"
gray="\e[0;37m\033[1m"
end="\033[0m\e[0m"

# ==============================================================
# HISTORY
# ==============================================================
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize

# ==============================================================
# PROMPT
# ==============================================================
get_ipaddr() {
    local interfaces=("tun0" "tap0" "eth0" "wlan0" "enp0s25" "wlp3s0")
    for iface in "${interfaces[@]}"; do
        if ip link show "$iface" &>/dev/null; then
            local ipaddr
            ipaddr=$(ip -4 addr show "$iface" 2>/dev/null | grep -Po 'inet \K\d{1,3}(\.\d{1,3}){3}' | head -n1)
            [[ -n $ipaddr ]] && { echo "$ipaddr"; return; }
        fi
    done
    echo "offline"
}

set_bash_prompt() {
    local esc=$'\033'
    local _red="${esc}[1;31m"
    local _blue="${esc}[1;34m"
    local _white="${esc}[1;37m"
    local _reset="${esc}[0m"
    local ipaddr
    ipaddr=$(get_ipaddr)
    local symbol='$'
    [[ $EUID -eq 0 ]] && symbol='#'
    PS1="${ipaddr}:\W${symbol} "
    case "$TERM" in
        xterm*|rxvt*|alacritty*|kitty*)
            PS1="\[${esc}]0;\u@${ipaddr}:\w\007\]${PS1}" ;;
    esac
}
PROMPT_COMMAND="set_bash_prompt"

# ==============================================================
# TERMINAL COLORS
# ==============================================================
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    export LS_COLORS="$LS_COLORS:ow=30;44:"

    export LESS_TERMCAP_mb=$'\E[1;31m'
    export LESS_TERMCAP_md=$'\E[1;36m'
    export LESS_TERMCAP_me=$'\E[0m'
    export LESS_TERMCAP_so=$'\E[01;33m'
    export LESS_TERMCAP_se=$'\E[0m'
    export LESS_TERMCAP_us=$'\E[1;32m'
    export LESS_TERMCAP_ue=$'\E[0m'
fi

# ==============================================================
# ALIASES
# ==============================================================

# --- Navigation ---
alias ls='lsd --icon never --group-directories-first'
alias ll='ls -lh'
alias lv='\ls -v1'
alias la='ls -a1'
alias l='ls -1'
alias lt='ls -1t'
alias lla='ls -lha'
alias lra='ls -lRa'
alias cls='clear'

# --- Files ---
alias cat='batcat --paging=never --style=plain'
alias less='batcat -p --color=always'
alias rm='rm -Iv'
alias del='/bin/rm -rfv'
alias copy='cp'
alias move='mv'
alias which='which -a'

# --- System ---
alias docker='sudo docker'
alias btop='sudo btop'
alias htop='sudo htop'
alias top='sudo top'
alias lsof='sudo lsof'
alias root='sudo su'
alias hosts='sudoedit /etc/hosts'

# --- Tools ---
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias igrep='grep -i'
alias grepi='grep -i'
alias diff='diff --color=auto'
alias ip='ip --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias cal='ncal -bwyM'
alias acs='apt-cache search'
alias ffetch='fastfetch --logo none --color red'

# --- Media ---
alias yp3='yt-dlp -x --audio-format mp3 --audio-quality 128K --output "%(title)s.%(ext)s"'
alias yp4='yt-dlp --format mp4 --output "%(title)s.%(ext)s"'
alias ydl='yt-dlp'
alias python='python -W ignore'
alias ris='ristretto'
alias kp='kolourpaint'
alias img='w3m -o ext_image_viewer=0'
alias tra='trans --brief'
alias verse="verse | tr -s ' ' | tr -d '' | sed 's/^ //'"
alias virtualbox='virtualbox -style fusion %U'
alias bspwmrc='. ~/.config/bspwm/bspwmrc'

# --- Pentest ---
alias smbmap='smbmap --no-banner'
alias autorecon='sudo autorecon'
alias responder='sudo responder'
alias caido='caido > /dev/null 2>&1'
alias target='setg rhost'
alias ctarget='unsetg rhost'
alias rhost='setg rhost'
alias rport='setg rport'
alias lhost='setg lhost'
alias lport='setg lport'
alias show-options='show_options'

# --- Encoding ---
alias rot13-encode='tr "A-Za-z" "N-ZA-Mn-za-m"'
alias rot13-decode='tr "A-Za-z" "N-ZA-Mn-za-m"'

# ==============================================================
# FUNCTIONS: SYSTEM
# ==============================================================

apt() {
    export DEBIAN_FRONTEND=noninteractive
    sudo /usr/bin/apt -y "$@"
}

realpath() {
    if [ -z "$1" ]; then
        echo "Usage: realpath <file>"
        return 1
    fi
    local file
    file=$(/usr/bin/realpath "$1") || return 1
    if ! command -v xsel &>/dev/null; then
        echo "Error: xsel is not installed."
        return 1
    fi
    echo "$file" | tr -d "\n" | xsel --clipboard --input || { echo "Error: Failed to copy to clipboard."; return 2; }
    echo "$file"
}

pwd() {
    local dir
    dir=$(/usr/bin/pwd)
    if ! command -v xsel &>/dev/null; then
        echo "Error: xsel is not installed."
        return 1
    fi
    echo "$dir" | tr -d "\n" | xsel --clipboard --input || { echo "Error: Failed to copy to clipboard."; return 2; }
    echo "$dir"
}

ff() {
    fastfetch \
        --logo none \
        --pipe \
        | grep -vE "\[40m|^$" \
        | tee /dev/tty | xclip -selection clipboard
}

colors() {
    bash "$HOME/.config/kitty/colors.sh"
}

rsp() {
    sudo rsync -rhazc --info=progress2 "$@"
}

zat() {
    zathura "$@" & disown
}

atril() {
    command atril "$@" & disown
}

w32() {
    export WINEARCH=win32
    export WINEPREFIX=~/.wine32
}

w64() {
    export WINEARCH=win64
    export WINEPREFIX=~/.wine
}

# ==============================================================
# FUNCTIONS: DEVELOPMENT
# ==============================================================

gip() {
    git add .
    git commit -m "$(date '+%Y-%m-%d_%H:%M:%S')"
    git push origin main --force
}

afu() {
    sudo apt update -y
    export DEBIAN_FRONTEND=noninteractive
    sudo -E apt-get \
        -o Dpkg::Options::="--force-confold" \
        -o Dpkg::Options::="--force-confdef" \
        dist-upgrade -q -y \
        --allow-downgrades --allow-remove-essential --allow-change-held-packages
    apt -y autoremove
    apt -y purge
    apt -y clean
}

java11() {
    echo "Switching to Java 11..."
    sudo update-java-alternatives -s java-1.11.0-openjdk-amd64
    export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
    java -version
}

java17() {
    echo "Switching to Java 17..."
    sudo update-java-alternatives -s java-1.17.0-openjdk-amd64
    export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
    java -version
}

# ==============================================================
# FUNCTIONS: SECURITY
# ==============================================================

show_options() {
    local allowed=("lhost" "lport" "rhost" "rport" "ssl" "proto")
    echo "┌── Current Configuration Options ──"
    for var in "${allowed[@]}"; do
        if [[ -v $var ]]; then
            printf "│ \033[1;36m%-6s\033[0m ▸ %s\n" "$var" "${!var}"
        else
            printf "│ \033[1;31m%-6s\033[0m ▸ %s\n" "$var" "(not set)"
        fi
    done
    echo "└───────────────────────────────────"
}

setg() {
    if [ $# -eq 0 ]; then
        echo "Usage: setg <variable> [value]"
        return 1
    fi

    local allowed=("lhost" "lport" "rport" "rhost" "ssl" "proto")
    local var_name="${1,,}"

    if [[ ! " ${allowed[*]} " =~ " ${var_name} " ]]; then
        echo "Error: '${var_name}' is not a configurable variable"
        echo "Allowed variables: ${allowed[*]}"
        return 1
    fi

    local var_value

    if [[ $var_name == "lhost" ]]; then
        if [ $# -eq 1 ]; then
            var_value=$(get_ipaddr)
            echo "Using auto-detected IP: $var_value"
        elif [[ "$2" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            var_value="$2"
        else
            local iface_ip
            iface_ip=$(ip -4 addr show "$2" 2>/dev/null | grep -Po 'inet \K\d{1,3}(\.\d{1,3}){3}' | head -n1)
            if [[ -n "$iface_ip" ]]; then
                var_value="$iface_ip"
                echo "Using IP from interface $2: $var_value"
            else
                var_value=$(get_ipaddr)
                echo "Falling back to auto-detected IP: $var_value"
            fi
        fi
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
    else
        if [ $# -ne 2 ]; then
            echo "Error: $var_name requires a value"
            return 1
        fi
        var_value="$2"
    fi

    local bashrc_actual
    bashrc_actual=$(readlink -f ~/.bashrc)
    local temp_file
    temp_file=$(mktemp)
    local var_exists=0

    while IFS= read -r line; do
        if [[ "$line" =~ ^export\ ${var_name}= ]]; then
            echo "export ${var_name}=\"$var_value\"" >> "$temp_file"
            var_exists=1
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$bashrc_actual"

    if [[ $var_exists -eq 0 ]]; then
        echo "export ${var_name}=\"$var_value\"" >> "$temp_file"
    fi

    cat "$temp_file" > "$bashrc_actual"
    rm "$temp_file"

    export ${var_name}="$var_value"
    echo "Global variable ${var_name} set to $var_value"

    if [[ $var_name == "rhost" ]]; then
        echo "$var_value" > ~/.current_target
        echo "Updated ~/.current_target"
    fi
}

unsetg() {
    if [ $# -ne 1 ]; then
        echo "Usage: unsetg <variable>"
        return 1
    fi

    local allowed=("lhost" "lport" "rport" "rhost" "ssl" "proto")
    local var_name="${1,,}"

    if [[ ! " ${allowed[*]} " =~ " ${var_name} " ]]; then
        echo "Error: '${var_name}' is not a configurable variable"
        echo "Allowed variables: ${allowed[*]}"
        return 1
    fi

    local bashrc_actual
    bashrc_actual=$(readlink -f ~/.bashrc)
    local temp_file
    temp_file=$(mktemp)

    while IFS= read -r line; do
        if [[ ! "$line" =~ ^export\ ${var_name}= ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$bashrc_actual"

    cat "$temp_file" > "$bashrc_actual"
    rm "$temp_file"

    unset "$var_name"
    echo "[+] Removed variable \"${var_name}\""

    if [[ $var_name == "rhost" ]]; then
        echo "none" > ~/.current_target
        echo "Cleared ~/.current_target"
    fi
    return 0
}

clear_all() {
    for i in "lhost" "lport" "rhost" "rport" "ssl" "proto"; do
        unsetg "$i"
    done
}

mac() {
    find /sys/class/net -mindepth 1 -maxdepth 1 ! -name lo -printf "%P: " \
        -execdir cat {}/address \; \
        | sort -n -r \
        | awk '{printf "\033[01;32m%s\033[0m - \033[01;31m%s\033[0m\n", $1, $2}'
}

macc() {
    sudo ifconfig "$1" down
    sudo macchanger -A "$1"
    sudo ifconfig "$1" up
}

rmk() {
    for item in "$@"; do
        if [[ -d "$item" ]]; then
            find "$item" -type f -exec scrub -p dod {} \; -exec shred -zvun 9 -v {} \;
            find "$item" -depth -type d -exec rmdir {} \;
            if [[ $? -eq 0 ]]; then
                echo "Directory $item and its contents have been securely removed."
            else
                echo "Failed to remove directory $item or some of its contents."
            fi
        elif [[ -f "$item" ]]; then
            scrub -p dod "$item"
            shred -zvun 9 -v "$item"
        else
            echo "Item $item does not exist or is neither a file nor a directory."
        fi
    done
}

get_resolution() {
    xrandr | grep '*' | awk '{print $1}'
}

lock_screen() {
    local resolution
    resolution=$(get_resolution)
    convert ~/.config/i3lock/stop.png -gravity center -background black \
        -extent "$resolution" ~/.config/i3lock/centered_stop.png
    i3lock -c 000000 -i ~/.config/i3lock/centered_stop.png
}

# ==============================================================
# FUNCTIONS: PENTEST
# ==============================================================

mkt() {
    local fname="$*"

    if [[ -z "$fname" ]]; then
        echo >&2 "Provide a folder name"
        echo >&2 "usage: mkt <folder name>"
        return 1
    fi

    echo -e "\n\033[1;34m[ $PWD/$fname ]\033[0m\n"

    if ! mkdir -p "$fname"/{recon/nmap,loot,exploit,www} 2>/dev/null; then
        echo >&2 "Error: Failed to create directory structure"
        return 2
    fi

    if ! touch "$fname"/{notes.md,log.txt,credentials.txt,summary.md} 2>/dev/null; then
        echo >&2 "Error: Failed to create initial files"
        return 3
    fi

    ls -ld "$fname"
    cd "$fname/recon/nmap" || return
}

smap() {
    sudo nmap -sS -p- --open -n -Pn --min-rate=5000 --disable-arp-ping \
        --stats-every=5s -oA tcp-all "$1"
}

umap() {
    sudo nmap -sU -F --open -n -Pn --min-rate=5000 --disable-arp-ping \
        --stats-every=5s -oA udp-all "$1"
}

xps() {
    if [ -z "$1" ]; then
        echo "Provide a file"
        echo "usage: xps <filename>"
        return 1
    fi

    local ip_Oaddress ports_Ofile command
    ip_Oaddress=$(grep --color=never -oP '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' "$1" | sort -u)
    ports_Ofile=$(grep --color=never -oP '\d{1,5}/open' "$1" | awk -F'/' '{print $1}' | xargs | tr " " ",")
    command="sudo nmap -sVC -p$ports_Ofile --disable-arp-ping --min-rate=5000 -n -Pn $ip_Oaddress --stats-every=5s -oA targeted"
    echo -e "[+] Command copied to clipboard, run:\n$command"
    echo -e "$command" | tr -d '\n' | xclip -sel clip
}

ww() {
    if [ $# -eq 0 ]; then
        echo "Usage: ww [whatweb options] <URLs>"
        return 1
    fi

    local target="${@: -1}"

    if [[ ! "$target" =~ ^(https?://|[a-zA-Z0-9.-]+\.[a-zA-Z]+|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
        echo "Error: Last argument doesn't appear to be a valid target"
        echo "Usage: ww [whatweb options] <URLs>"
        return 1
    fi

    local clean_name base_filename txt_file xml_file json_file
    clean_name=$(echo "$target" | sed -E 's/https?:\/\///g' | sed -E 's/[:\/]/_/g' | sed -E 's/\./_/g')
    base_filename="${clean_name}"
    txt_file="./${base_filename}.txt"
    xml_file="./${base_filename}.xml"
    json_file="./${base_filename}.json"

    local -a options=()
    if [ $# -gt 1 ]; then
        options=("${@:1:$#-1}")
    fi

    echo -e "[+] Scanning $target..."
    echo -e "[+] Options: ${options[*]}"
    echo -e "[+] Results will be saved to:\n----------------------"
    echo -e "\tText:  $txt_file"
    echo -e "\tXML:   $xml_file"
    echo -e "\tJSON:  $json_file"
    echo -e "----------------------\n"

    whatweb -v "${options[@]}" --log-xml="$xml_file" --log-json="$json_file" "$target" | tee "$txt_file"
    echo "Scan complete!"
}

_xmap_merge_html_reports() {
    local target_clean="$1"
    shift
    local html_files=("$@")

    cat > "targeted-${target_clean}.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Consolidated Scan Report for ${target_clean}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 20px; margin: -20px -20px 20px -20px; border-radius: 5px 5px 0 0; }
        .protocol-section { background: white; padding: 20px; margin: 20px 0; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        .tcp  { border-left: 5px solid #4CAF50; }
        .udp  { border-left: 5px solid #2196F3; }
        .sctp { border-left: 5px solid #FF9800; }
        h1 { margin: 0; }
        h2 { color: #333; margin-top: 0; padding-bottom: 10px; border-bottom: 2px solid #eee; }
        .timestamp { color: #ecf0f1; font-size: 0.9em; margin-top: 10px; }
        .protocol-content { margin-top: 15px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { text-align: left; padding: 8px; }
        tr:nth-child(even) { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Consolidated Scan Report</h1>
        <p class="timestamp">Generated on: $(date)</p>
        <p class="timestamp">Target: ${target_clean}</p>
    </div>
EOF

    for html_file in "${html_files[@]}"; do
        local protocol="unknown"
        local protocol_name="Unknown"
        if [[ "$html_file" == *"tcp-svc-"* ]]; then
            protocol="tcp"; protocol_name="TCP"
        elif [[ "$html_file" == *"udp-svc-"* ]]; then
            protocol="udp"; protocol_name="UDP"
        elif [[ "$html_file" == *"sctp-svc-"* ]]; then
            protocol="sctp"; protocol_name="SCTP"
        fi

        cat >> "targeted-${target_clean}.html" <<EOF
    <div class="protocol-section ${protocol}">
        <h2>${protocol_name} Service Detection Results</h2>
        <div class="protocol-content">
EOF
        if [[ -f "$html_file" ]]; then
            sed -n '/<body>/,/<\/body>/p' "$html_file" \
                | grep -v '<body>' | grep -v '</body>' \
                | sed 's/<h1>Nmap/<h3>Nmap/g' \
                | sed 's/<\/h1>/<\/h3>/g' >> "targeted-${target_clean}.html"
        fi

        cat >> "targeted-${target_clean}.html" <<EOF
        </div>
        <p style="color: #888; font-size: 0.85em; margin-top: 15px;">Source: $html_file</p>
    </div>
EOF
    done

    cat >> "targeted-${target_clean}.html" <<EOF
</body>
</html>
EOF
    echo "Consolidated HTML report generated: targeted-${target_clean}.html"
}

xmap() {
    local target=""
    local scan_types="tcp,udp"
    local min_rate=5000
    local tcp_only=false
    local udp_only=false
    local sctp_scan=false
    local run_service_scan=true
    local generate_html=true

    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--tcp)
                tcp_only=true; scan_types="tcp"; shift ;;
            -u|--udp)
                udp_only=true; scan_types="udp"; shift ;;
            -s|--sctp)
                sctp_scan=true
                [[ "$scan_types" != "tcp" && "$scan_types" != "udp" ]] && scan_types="sctp"
                shift ;;
            -r|--range)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    min_rate="$2"; shift 2
                else
                    echo "Error: --range requires a numeric value"; return 1
                fi ;;
            --no-service|--no-svc)
                run_service_scan=false; shift ;;
            --no-html)
                generate_html=false; shift ;;
            --help|-h)
                echo "Usage: xmap <target> [options]"
                echo ""
                echo "Options:"
                echo "  -t, --tcp         TCP scan only"
                echo "  -u, --udp         UDP scan only"
                echo "  -s, --sctp        SCTP scan (along with other selected scans)"
                echo "  -r, --range N     Set minimum packet rate (default: 5000)"
                echo "  --no-service      Skip service detection (-sVC) scan"
                echo "  --no-html         Skip HTML report generation"
                echo "  -h, --help        Show this help message"
                echo ""
                echo "Examples:"
                echo "  xmap 192.168.1.1              # Full scan: TCP+UDP+Service+HTML"
                echo "  xmap 192.168.1.1 -t           # TCP only with service detection"
                echo "  xmap 192.168.1.1 -u --no-html # UDP only, no HTML report"
                echo "  xmap 192.168.1.1 --no-service # Skip service detection"
                return 0 ;;
            -*)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                return 1 ;;
            *)
                target="$1"; shift ;;
        esac
    done

    if [[ -z "$target" ]]; then
        echo "Error: Target IP/hostname is required"
        echo "Usage: xmap <target> [options]"
        return 1
    fi

    local target_clean="${target//\//_}"

    if [[ "$tcp_only" = true && "$udp_only" = true ]]; then
        echo "Warning: Both -t and -u specified, defaulting to both TCP and UDP"
        scan_types="tcp,udp"
    fi

    local scan_array=()
    if [[ "$scan_types" == "tcp" ]]; then
        scan_array=("tcp")
    elif [[ "$scan_types" == "udp" ]]; then
        scan_array=("udp")
    elif [[ "$scan_types" == "tcp,udp" ]]; then
        scan_array=("tcp" "udp")
    fi
    [[ "$sctp_scan" = true ]] && scan_array+=("sctp")

    echo "Starting xmap scan for target: $target"
    echo "Scan types: ${scan_array[*]}"
    echo "Minimum rate: $min_rate packets/sec"
    echo "Service detection: $([ "$run_service_scan" = true ] && echo "Enabled" || echo "Disabled")"
    echo "HTML report: $([ "$generate_html" = true ] && echo "Enabled" || echo "Disabled")"
    echo ""

    for scan_type in "${scan_array[@]}"; do
        case $scan_type in
            tcp)
                echo "=== Starting TCP SYN scan (all ports) ==="
                sudo nmap -sS -p- --open -n -Pn --min-rate="$min_rate" --disable-arp-ping \
                    --stats-every=5s -oA "tcp-all-$target_clean" "$target"
                echo "" ;;
            udp)
                echo "=== Starting UDP scan (top 100 ports) ==="
                sudo nmap -sU -F --open -n -Pn --min-rate="$min_rate" --disable-arp-ping \
                    --stats-every=5s -oA "udp-all-$target_clean" "$target"
                echo "" ;;
            sctp)
                echo "=== Starting SCTP scan ==="
                sudo nmap -sY -p- --open -n -Pn --min-rate="$min_rate" --disable-arp-ping \
                    --stats-every=5s -oA "sctp-all-$target_clean" "$target"
                echo "" ;;
        esac
    done

    if [[ "$run_service_scan" = true ]]; then
        echo "=== Processing results for service detection ==="

        local target_ip=""
        for scan_type in "${scan_array[@]}"; do
            local scan_file="${scan_type}-all-${target_clean}.nmap"
            if [[ -f "$scan_file" && -z "$target_ip" ]]; then
                target_ip=$(grep -oP '^Nmap scan report for \K[0-9.]+' "$scan_file" 2>/dev/null \
                    || grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "$scan_file" | head -1)
                [[ -n "$target_ip" ]] && break
            fi
        done

        if [[ -z "$target_ip" ]]; then
            echo "Warning: Could not extract target IP — skipping service detection"
            run_service_scan=false
        else
            echo "Target IP: $target_ip"
            local service_detection_files=()

            for scan_type in "${scan_array[@]}"; do
                local scan_file="${scan_type}-all-${target_clean}.nmap"
                if [[ -f "$scan_file" ]]; then
                    echo "Checking $scan_type ports..."
                    local scan_ports
                    scan_ports=$(grep -E '^[0-9]+/.*open' "$scan_file" | awk -F'/' '{print $1}' | xargs | tr " " "," 2>/dev/null)

                    if [[ -n "$scan_ports" ]]; then
                        echo "Found $scan_type ports: $scan_ports"
                        case $scan_type in
                            tcp)
                                echo "=== Running TCP service detection ==="
                                sudo nmap -sVC -p"$scan_ports" --disable-arp-ping --min-rate="$min_rate" \
                                    -n -Pn "$target_ip" --stats-every=5s -oA "tcp-svc-$target_clean"
                                service_detection_files+=("tcp-svc-${target_clean}.xml") ;;
                            udp)
                                echo "=== Running UDP service detection ==="
                                sudo nmap -sUVC -p"$scan_ports" --disable-arp-ping --min-rate="$min_rate" \
                                    -n -Pn "$target_ip" --stats-every=5s -oA "udp-svc-$target_clean"
                                service_detection_files+=("udp-svc-${target_clean}.xml") ;;
                            sctp)
                                echo "=== Running SCTP service detection ==="
                                sudo nmap -sY -sV -p"$scan_ports" --disable-arp-ping --min-rate="$min_rate" \
                                    -n -Pn "$target_ip" --stats-every=5s -oA "sctp-svc-$target_clean"
                                service_detection_files+=("sctp-svc-${target_clean}.xml") ;;
                        esac
                        echo ""
                    else
                        echo "No open $scan_type ports found"
                    fi
                fi
            done

            if [[ "$generate_html" = true && ${#service_detection_files[@]} -gt 0 ]]; then
                echo "=== Generating consolidated HTML report ==="
                if command -v xsltproc >/dev/null; then
                    local html_files=()
                    for xml_file in "${service_detection_files[@]}"; do
                        if [[ -f "$xml_file" ]]; then
                            local html_output="${xml_file%.xml}.html"
                            echo "Converting $xml_file to HTML..."
                            xsltproc -o "$html_output" "$xml_file"
                            [[ $? -eq 0 && -f "$html_output" ]] && html_files+=("$html_output") \
                                || echo "Warning: Failed to convert $xml_file"
                        fi
                    done
                    if [[ ${#html_files[@]} -gt 0 ]]; then
                        echo "Merging HTML reports..."
                        _xmap_merge_html_reports "$target_clean" "${html_files[@]}"
                    else
                        echo "Error: No HTML files were generated"
                    fi
                    if [[ -f "targeted-${target_clean}.html" ]]; then
                        xdg-open "targeted-${target_clean}.html" 2>/dev/null &
                    fi
                else
                    echo "Warning: xsltproc not installed — cannot generate HTML report"
                    echo "Install with: sudo apt-get install xsltproc"
                fi
            fi
        fi
    fi

    echo "=== Scan Summary ==="
    echo ""

    local created_files=()
    for scan_type in "${scan_array[@]}"; do
        for ext in ".nmap" ".gnmap" ".xml"; do
            local file="${scan_type}-all-${target_clean}${ext}"
            [[ -f "$file" ]] && created_files+=("$file")
        done
    done

    if [[ "$run_service_scan" = true ]]; then
        for scan_type in "${scan_array[@]}"; do
            for ext in ".nmap" ".gnmap" ".xml"; do
                local file="${scan_type}-svc-${target_clean}${ext}"
                [[ -f "$file" ]] && created_files+=("$file")
            done
        done
        [[ -f "targeted-${target_clean}.html" ]] && created_files+=("targeted-${target_clean}.html")
    fi

    if [[ ${#created_files[@]} -gt 0 ]]; then
        echo "Created files:"
        for file in "${created_files[@]}"; do
            ls -lh "$file" 2>/dev/null || echo "  $file"
        done
    fi

    echo ""
    echo "=== Open Ports Summary ==="
    for scan_type in "${scan_array[@]}"; do
        local scan_file="${scan_type}-all-${target_clean}.nmap"
        if [[ -f "$scan_file" ]]; then
            local open_count
            open_count=$(grep -c '^[0-9]\+/.*open' "$scan_file" 2>/dev/null || echo "0")
            echo "${scan_type^^}: $open_count open ports"
        fi
    done

    if [[ "$run_service_scan" = true ]]; then
        echo ""
        echo "=== Service Detection Results ==="
        for scan_type in "${scan_array[@]}"; do
            local svc_file="${scan_type}-svc-${target_clean}.nmap"
            [[ -f "$svc_file" ]] && echo "${scan_type^^} services in: ${scan_type}-svc-${target_clean}.nmap"
        done
        if [[ "$generate_html" = true && -f "targeted-${target_clean}.html" ]]; then
            echo "Consolidated HTML report: targeted-${target_clean}.html"
        fi
    fi
}

# ==============================================================
# PATH & EXPORTS
# ==============================================================
export TERM=xterm-256color
export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export GOPATH="$HOME/go"
export PATH="$PATH:$HOME/go/bin:$HOME/.pdtm/go/bin:$HOME/.local/bin:/usr/local/bin:/opt/pentest/bin/linux:$HOME/.cargo/bin"
export PATH="$PATH:$HOME/.rvm/bin"

# ==============================================================
# COMPLETIONS
# ==============================================================
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

[ -f ~/.bash_aliases ] && . ~/.bash_aliases
