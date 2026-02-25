# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
*i*) ;;
*) return ;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
xterm-color | *-256color) color_prompt=yes ;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
  if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    # We have color support; assume it's compliant with Ecma-48
    # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
    # a case would tend to support setf rather than setaf.)
    color_prompt=yes
  else
    color_prompt=
  fi
fi

# The following block is surrounded by two delimiters.
# These delimiters must not be modified. Thanks.
# START KALI CONFIG VARIABLES

if [ "$color_prompt" = yes ]; then

  # --- IP Detection Function ---
  get_ipaddr() {
    local interfaces=("tun0" "tap0" "eth0" "wlan0" "wlan1")
    for iface in "${interfaces[@]}"; do
      if ip link show "$iface" &>/dev/null; then
        local ipaddr=$(ip -4 addr show "$iface" 2>/dev/null | grep -Po 'inet \K\d{1,3}(\.\d{1,3}){3}' | head -n1)
        [[ -n $ipaddr ]] && {
          echo "$ipaddr"
          return
        }
      fi
    done
    echo "offline"
  }

  # --- Red-Themed Prompt with IP ---
  # Use $'\033' so the terminal gets real ESC (single-quoted \033 is literal = wrong width + no color reset).
  # All non-printing chars in \[ \] so bash knows prompt length (stops long-line overwriting).
  set_bash_prompt() {
    local esc=$'\033'
    local ipaddr=$(get_ipaddr)
    local symbol='$'
    [[ $EUID -eq 0 ]] && symbol='#'
    # Red prompt, then reset so typed text is default color; \[ \] = zero width for line length
    PS1="\[${esc}[1;31m\][\u@${ipaddr}\w]${symbol} \[${esc}[0m\]"
    # Optional: set xterm/kitty window title (non-printing, so also in \[ \])
    case "$TERM" in
    xterm*|rxvt*|alacritty*|kitty*) PS1="\[${esc}]0;\u@${ipaddr}:\w\007\]${PS1}" ;;
    esac
  }
  PROMPT_COMMAND="set_bash_prompt"

  unset prompt_color
  unset info_color
  unset prompt_symbol
else
  PS1='[\u@\h:\w]\$ '
fi
unset color_prompt force_color_prompt

[ "$NEWLINE_BEFORE_PROMPT" = yes ] && PROMPT_COMMAND="PROMPT_COMMAND=echo"

# enable color support of ls, less and man, and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  export LS_COLORS="$LS_COLORS:ow=30;44:" # fix ls color for folders with 777 permissions

  #alias ls='ls --color=auto'
  alias dir='dir --color=auto'
  alias vdir='vdir --color=auto'

  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
  alias diff='diff --color=auto'
  alias ip='ip --color=auto'

  export LESS_TERMCAP_mb=$'\E[1;31m'  # begin blink
  export LESS_TERMCAP_md=$'\E[1;36m'  # begin bold
  export LESS_TERMCAP_me=$'\E[0m'     # reset bold/blink
  export LESS_TERMCAP_so=$'\E[01;33m' # begin reverse video
  export LESS_TERMCAP_se=$'\E[0m'     # reset reverse video
  export LESS_TERMCAP_us=$'\E[1;32m'  # begin underline
  export LESS_TERMCAP_ue=$'\E[0m'     # reset underline
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases

# --- Aliases ---
alias ls='lsd --icon never --group-directories-first'
alias ll='ls -lh'
alias la='ls -a1'
alias l='ls -1'
alias lt='ls -1t'
alias lla='ls -lha'
alias cat='batcat --paging=never --style=plain'
alias cls='clear'
alias ffetch='fastfetch --logo none --color red'
alias yp3='youtube-dl -x --audio-format mp3 --audio-quality 128K --output "%(title)s.%(ext)s"'
alias yp4='youtube-dl --format mp4 --output "%(title)s.%(ext)s"'
alias smbmap='smbmap --no-banner'
alias del='/bin/rm -rfv'

# --- Functions ---
mkt() {
  if [ -z "$1" ]; then
    echo "Usage: mkt <foldername>"
  else
    mkdir -p "$1"/{content,exploits,nmap}
    cd "$1" || return
    ls -lha
  fi
}

xps() {
  if [ -z "$1" ]; then
    echo "Usage: xps <filename>"
  else
    ip_Oaddress=$(grep -oP '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' "$1" | sort -u)
    ports_Ofile=$(grep -oP '\d{1,5}/open' "$1" | awk -F/ '{print $1}' | xargs | tr " " ",")
    echo -e "sudo nmap -sVC -p$ports_Ofile --min-rate=5000 -n -Pn $ip_Oaddress -oN targeted" | xclip -sel clip
    echo "Command copied to clipboard!"
  fi
}

java11() {
  echo "Switching to Java 11..."
  sudo update-java-alternatives -s java-1.11.0-openjdk-amd64
  export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
  java -version
}

java17() {
  echo "Switching to Java 17..."
  sudo update-java-alternatives -s java-1.17.0-openjdk-amd64
  export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
  java -version
}

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

export TERM=xterm-256color

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
