ff() {
    fastfetch \
      --logo none \
      --pipe \
      | grep -vE "\[40m|^$" \
      | tee /dev/tty | xclip -selection clipboard
}

function colors() {
  bash "$HOME/.config/kitty/colors.sh"
}

function apt() {
  export DEBIAN_FRONTEND=noninteractive
  sudo /usr/bin/apt -y "$@"
}


center() {
    local text="$1"
    local width=$(tput cols)
    local len=${#text}
    local pad=$(( (width - len) / 2 ))
    [ $pad -lt 0 ] && pad=0
    printf "%${pad}s%s\n" "" "$text"
}
