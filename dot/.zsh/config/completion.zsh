# Completion
autoload -Uz compinit
# Full security check only if the dump is older than 24h; otherwise reuse it (-C)
if [[ -n ~/.cache/zcompdump(#qN.mh+24) || ! -s ~/.cache/zcompdump ]]; then
  compinit -d ~/.cache/zcompdump
else
  compinit -C -d ~/.cache/zcompdump
fi

autoload -Uz bashcompinit && bashcompinit
complete -C '/usr/local/bin/aws_completer' aws

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
