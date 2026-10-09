# exports
export PATH=$PATH:$HOME:/opt/bin:$HOME/.local/bin:/usr/bin/ruby3.0:$HOME/.go/bin:$HOME/.cargo/bin
export PATH=$PATH:$HOME/.rvm/bin
export DEBIAN_FRONTEND=noninteractive
export GOPATH=$HOME/.go
export GEM_HOME="$HOME/.gems"
export PATH="$HOME/.gems/bin:$PATH"
export _JAVA_AWT_WM_NONREPARENTING=1
export TERM=xterm-256color
export PATH="$PATH:/usr/local/zig"
export PATH="$PATH:/snap/bin"
export PATH="$PATH:$HOME/go/bin:$HOME/.pdtm/go/bin:$HOME/.local/bin:/usr/local/bin:/opt/pentest/bin/linux:$HOME/.cargo/bin"



### capture the flag variables ###
export lhost="$(get_ipaddr)"

### X display auto-adapt ###
# Long-lived shells (tmux servers, old terminals) keep the DISPLAY of a previous login
# (e.g. :0 from lightdm while Ly's session is on :1). If a local DISPLAY points at an X
# server that isn't running, switch to the one that is. Skipped over SSH/forwarded displays.
_adapt_display() {
  [[ -n $SSH_CONNECTION ]] && return
  [[ -n $DISPLAY && $DISPLAY != :<->* ]] && return
  local -a active
  active=(${(f)"$(ps -C Xorg,Xwayland -o args= 2>/dev/null | grep -oE ' :[0-9]+' | tr -d ' ')"})
  (( ${#active} )) || return
  [[ -n ${active[(r)${DISPLAY%%.*}]} ]] || export DISPLAY=${active[1]}
}
_adapt_display
autoload -Uz add-zsh-hook
add-zsh-hook precmd _adapt_display
