# Plugins (zsh-autocomplete is loaded earlier, in config/completion.zsh,
# because it has to come before compinit/compdef).

# Auto suggestions — async so a slow history/completion lookup never blocks typing
if [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    ZSH_AUTOSUGGEST_USE_ASYNC=1
    ZSH_AUTOSUGGEST_MANUAL_REBIND=1          # don't re-wrap widgets before every prompt
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=60       # don't suggest for huge pasted lines
    ZSH_AUTOSUGGEST_STRATEGY=(history)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#999'
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Syntax highlighting — must be sourced last
if [[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    ZSH_HIGHLIGHT_MAXLENGTH=300              # skip highlighting very long buffers
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
