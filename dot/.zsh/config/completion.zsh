# Completion — compinit runs exactly ONCE per shell.
#
# zsh-autocomplete (live completion menu while typing) is DISABLED: completion
# lists only appear on Tab. Its settings below are kept for reference; set
# _bspwn_autocomplete=1 here to use it again. When used, it must be sourced
# before any compdef and runs compinit itself. Otherwise: a cached compinit
# (-C: skip the security audit; full rebuild at most once a day).
_bspwn_autocomplete=0
if (( _bspwn_autocomplete )) && [[ -r /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]]; then
    # Tuned for a slow CPU: the live menu only runs after a pause, on 3+ chars,
    # and shows a short list; history search is kept (cheap), file globbing is not.
    zstyle ':autocomplete:*' delay 0.25
    zstyle ':autocomplete:*' min-input 3
    zstyle -e ':autocomplete:*:*' list-lines 'reply=( $(( LINES / 4 > 8 ? 8 : LINES / 4 )) )'
    # no live recent-dirs/paths menu on an empty prompt
    zstyle ':autocomplete:*' ignored-input '..##'
    source /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
else
    autoload -Uz compinit
    _zcd=${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump
    if [[ -n $_zcd(#qN.mh-24) ]]; then compinit -C -d $_zcd; else compinit -d $_zcd; fi
    unset _zcd
    zstyle ':completion:*:*:*:*:*' menu select
fi

autoload -Uz bashcompinit && bashcompinit
[[ -x /usr/local/bin/aws_completer ]] && complete -C '/usr/local/bin/aws_completer' aws

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
# cache expensive completers (apt, dpkg, man pages, ...)
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ${XDG_CACHE_HOME:-$HOME/.cache}/zsh-compcache

# Left/Right keep moving the cursor even when the autocomplete menu is open
# (the menu used to hijack them to change the selected item). Up/Down/Tab/Shift-Tab
# still navigate the menu.
if (( _bspwn_autocomplete )) && [[ -r /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]]; then
    _ac_cursor_left()  { zle send-break; zle .backward-char }
    _ac_cursor_right() { zle send-break; zle .forward-char }
    zle -N _ac_cursor_left; zle -N _ac_cursor_right
    bindkey -M menuselect '^[[D' _ac_cursor_left  '^[OD' _ac_cursor_left
    bindkey -M menuselect '^[[C' _ac_cursor_right '^[OC' _ac_cursor_right
    bindkey -M menuselect '^I' menu-complete '^[[Z' reverse-menu-complete
    # Shift-Tab in the normal prompt: open menu backwards instead of undo
fi
# Shift-Tab in the normal prompt: open the completion menu backwards instead of undo
bindkey '^[[Z' reverse-menu-complete
unset _bspwn_autocomplete
