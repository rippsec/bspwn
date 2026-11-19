# ~/.zshrc - Main configuration file
# Sources modules from ~/.zsh/

# Source all modules in order
if [ -d ~/.zsh ]; then
    # Config files first
    for config in ~/.zsh/config/*.zsh; do
        source "$config"
    done
    
    # Prompt system
    for prompt in ~/.zsh/prompt/*.zsh; do
        source "$prompt"
    done
    
    # Plugins
    for plugin in ~/.zsh/plugins/*.zsh; do
        source "$plugin"
    done
    
    # Aliases
    for alias_file in ~/.zsh/aliases/*.zsh; do
        source "$alias_file"
    done
    
    # Functions
    for func in ~/.zsh/functions/*.zsh; do
        source "$func"
    done

    # Pentest Framework
     for pentest_tool in ~/.zsh/pentest/*.zsh; do
      source "$pentest_tool" || :
     done

    # Remaining
    source ~/.zsh/exports.zsh
    source ~/.zsh/theme.zsh
fi

# Keep only essential settings that must be in main zshrc
PROMPT_EOL_MARK=''

# Debian chroot (from lines 113-116)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi
# Firefox optimized for older hardware
alias firefox-fast='firefox-esr --no-remote'

# fnm
FNM_PATH="/home/rip/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell zsh)"
fi


# Generated for pdtm. Do not edit.
export PATH=$PATH:/home/rip/.pdtm/go/bin



export RUSTICL_ENABLE=iris
export rhost="192.168.1.1"

# readable world-writable dirs (default 34;42 blue-on-green is unreadable in this palette)
export LS_COLORS="${LS_COLORS}:ow=01;34:tw=01;34"
