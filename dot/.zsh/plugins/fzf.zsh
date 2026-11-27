# fzf — Ctrl+F: fuzzy-find any file/dir on the system and paste it on the command line.
# Uses fd (fdfind) instead of find (faster); results stream in, so the list is usable immediately.
if [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] && (( $+commands[fdfind] )); then
    # search from / ; skip virtual / noisy trees so results stay fast and relevant
    export FZF_CTRL_T_COMMAND="fdfind --hidden --color=never \
        --exclude proc --exclude sys --exclude dev --exclude run --exclude tmp \
        --exclude .git --exclude node_modules --exclude .cache --exclude snap --exclude .steam --exclude .miniconda3 --exclude .npm --exclude .cargo --exclude proc \
        . /"
    export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --info=inline --scheme=path --exact --ignore-case"
    (( $+commands[batcat] )) && export FZF_CTRL_T_OPTS="--preview 'batcat --color=always --style=plain --line-range=:60 {} 2>/dev/null || ls -la {}' --preview-window=right:50%:hidden --bind=ctrl-/:toggle-preview"
    source /usr/share/doc/fzf/examples/key-bindings.zsh
    # key-bindings.zsh binds Ctrl+T / Ctrl+R / Alt+C; add Ctrl+F for the file widget
    bindkey -M emacs '^F' fzf-file-widget
    bindkey -M viins '^F' fzf-file-widget 2>/dev/null
    # fzf history list on Ctrl+R is DISABLED: Ctrl+R is zsh's own incremental history search.
    # (To get the fzf list back: bind '^R' to fzf-history-widget instead.)
    bindkey -M emacs '^R' history-incremental-search-backward
    bindkey -M viins '^R' history-incremental-search-backward 2>/dev/null
fi
