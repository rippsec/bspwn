# History config
HISTFILE=~/.zsh_history
HISTSIZE=99999
SAVEHIST=99999
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_verify

# Complete history
alias history="history 0"
