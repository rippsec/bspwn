#!/usr/bin/env bash
# ~/.config/polybar/scripts/pwmenu.sh

uptime=$(uptime -p | sed -e 's/up //g')

# Rofi command with theme
rofi_command="rofi -theme $HOME/.config/rofi/pwmenu.rasi"

# Options (with standard Unicode/emojis)
shutdown="󰐥 Shutdown"
reboot=" Restart"
lock=" Lock"
suspend="󰒲 Sleep"
logout=" Logout"


# Function: Message dialog
msg() {
	rofi -theme "$dir/message.rasi" -e "$1"
}

# Rofi menu options
options="$lock\n$suspend\n$logout\n$reboot\n$shutdown"

# Get user selection
chosen=$(echo -e "$options" | $rofi_command -p "Uptime: $uptime" -dmenu -selected-row 0)

# Handle the selected option
case "$chosen" in
	$shutdown)
		shutdown -h now
		;;
	$reboot)
		 shutdown -r now
		;;
	$lock)
		if command -v slock; then
			slock
		else
			msg "Lock command 'slock' not found. Please install it."
		fi
		;;
	$suspend)
		 mpc -q pause; amixer set Master mute; systemctl suspend
		;;
	$logout)
		bspc quit
		;;
#   *)
#	  msg "No valid option selected."
#		;;
esac
