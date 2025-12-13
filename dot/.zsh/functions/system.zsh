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

function clear_all(){
    for i in "lhost" "lport" "rhost" "rport" "ssl" "proto"; do
        unsetg "$i";
    done
}
