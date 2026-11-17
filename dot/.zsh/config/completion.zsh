# Completion — compinit runs exactly ONCE per shell.
#
# zsh-autocomplete (live completion menu while typing) must be sourced before
# any compdef and runs compinit itself. Without it, fall back to a cached
# compinit (-C: skip the security audit; full rebuild at most once a day).
if [[ -r /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]]; then
    # less work per keystroke: wait for a short pause and 2+ typed chars
    zstyle ':autocomplete:*' delay 0.12
    zstyle ':autocomplete:*' min-input 2
    zstyle -e ':autocomplete:*:*' list-lines 'reply=( $(( LINES / 3 )) )'
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
