# Auto suggestions
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    . /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#999'
fi

# Syntax highlighting — must be sourced last
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    . /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

#if [ -f /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]; then
#    . /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
#fi

