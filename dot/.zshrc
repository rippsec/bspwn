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
export lhost="$(get_ipaddr)"
# Firefox optimized for older hardware
alias firefox-fast='firefox-esr --no-remote'
export rhost="10.129.244.81"
