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

# fnm
FNM_PATH="/home/rip/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell zsh)"
fi


# Generated for pdtm. Do not edit.
export PATH=$PATH:/home/rip/.pdtm/go/bin


# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/rip/.miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/rip/.miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/rip/.miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/rip/.miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export rhost="192.168.137.187"
