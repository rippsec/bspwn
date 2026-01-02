# Prompt setup
setopt prompt_subst

# Function to shorten path
shorten_path() {
    local path=${PWD/#$HOME/\~}
    local is_absolute=0
    [[ "$path" == /* ]] && is_absolute=1
    local elements=("${(@s:/:)path}")
    elements=("${(@)elements:#}")
    local shortened=""

    if [[ "$path" == "~" ]]; then
        echo "~"
        return
    fi

    if [[ "$path" == "~/"* ]]; then
        shortened="~/"
        elements=("${elements[@]:1}")
    elif (( is_absolute )); then
        shortened="/"
    fi

    local num_elements=${#elements[@]}

    for ((i=1; i < num_elements; i++)); do
        shortened+="${elements[i][1]}/"
    done

    if (( num_elements > 0 )); then
        shortened+="${elements[-1]}"
    fi

    [[ "$shortened" == "/" ]] && echo "/" && return
    echo "${shortened}"
}

# Update your update_prompt function
update_prompt() {
    # Determine symbol & prompt based on user
    local symbol='@'
    local FGCOLOR='%{%B%F{white}%}'
    local BGCOLOR='' #'%{%B%K{white}%}'
    local ENDCOLOR='%{%b%f%k%}'
    # ROOT INDICATOR
    if [[ $EUID -eq 0 ]]; then
        symbol='󰚌'
        FGCOLOR='%{%B%F{white}%}'
        BGCOLOR='%{%K{#ff0000}%}'
        ENDCOLOR='%{%b%f%k%}'
    fi

    case $PROMPT_STYLE in
        detailed)
            local ipaddr=$(get_ipaddr)
            PROMPT="${BGCOLOR}${FGCOLOR}[%n${symbol}$ipaddr:%~]%(#.#.$)${ENDCOLOR}"
            ;;
        ipdir)
            local ipaddr=$(get_ipaddr)
            PROMPT="${BGCOLOR}${FGCOLOR}[$ipaddr:%~]%(#.#.$)${ENDCOLOR}"
            ;;
        dir)
            PROMPT="${BGCOLOR}${FGCOLOR}[%~]%(#.#.$)${ENDCOLOR}"
            ;;
        minimal)
            PROMPT="${BGCOLOR}${FGCOLOR}%(#.#.$)${ENDCOLOR}"
            ;;
    esac
}

# Function to get next prompt style in sequence
get_next_prompt_style() {
    local current="$1"
    local direction="$2"
    
    if [[ "$ENABLE_DETAILED_PROMPT" == true ]]; then
        if [[ "$direction" == "forward" ]]; then
            case "$current" in
                detailed) echo "ipdir" ;;
                ipdir) echo "dir" ;;
                dir) echo "minimal" ;;
                *) echo "detailed" ;;
            esac
        else
            case "$current" in
                minimal) echo "dir" ;;
                dir) echo "ipdir" ;;
                ipdir) echo "detailed" ;;
                *) echo "minimal" ;;
            esac
        fi
    else
        if [[ "$direction" == "forward" ]]; then
            case "$current" in
                ipdir) echo "dir" ;;
                dir) echo "minimal" ;;
                detailed) echo "ipdir" ;;
                *) echo "ipdir" ;;
            esac
        else
            case "$current" in
                minimal) echo "dir" ;;
                dir) echo "ipdir" ;;
                detailed) echo "dir" ;;
                *) echo "minimal" ;;
            esac
        fi
    fi
}

# Toggle prompt styles forward
toggle_prompt() {
    PROMPT_STYLE=$(get_next_prompt_style "$PROMPT_STYLE" "forward")
    update_prompt
    zle reset-prompt
}

zle -N toggle_prompt
bindkey '^P' toggle_prompt

# Toggle prompt styles in reverse order
toggle_prompt_reverse() {
    PROMPT_STYLE=$(get_next_prompt_style "$PROMPT_STYLE" "reverse")
    update_prompt
    zle reset-prompt
}

zle -N toggle_prompt_reverse
bindkey '^[^P' toggle_prompt_reverse

# Convenience functions
enable_detailed_prompt() {
    ENABLE_DETAILED_PROMPT=true
    echo "Detailed prompt enabled. Use Ctrl+P to cycle through all styles."
}

disable_detailed_prompt() {
    ENABLE_DETAILED_PROMPT=false
    if [[ "$PROMPT_STYLE" == "detailed" ]]; then
        PROMPT_STYLE="ipdir"
        update_prompt
        zle reset-prompt 2>/dev/null || true
    fi
    echo "Detailed prompt disabled. Cycling through: ipdir -> dir -> minimal"
}

# Transient Prompt
zle-line-init() {
    emulate -L zsh
    [[ $CONTEXT == start ]] || return 0

    local ret
    while true; do
        zle .recursive-edit
        ret=$?
        [[ $ret == 0 && $KEYS == $'\4' ]] || break
        [[ -o ignore_eof ]] || exit 0
    done

    local saved_prompt=$PROMPT
    PROMPT="%(#.#.$) "
    zle .reset-prompt
    PROMPT=$saved_prompt

    (( ret )) && zle .send-break || zle .accept-line
    return ret
}
zle -N zle-line-init

# Final prompt setup
autoload -Uz add-zsh-hook
add-zsh-hook precmd update_prompt
