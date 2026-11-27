# Hardware and user specifics in this repo (what to check on another machine)

The setup was built on a ThinkPad T450 (1600x900 panel, Intel graphics, two batteries "internal" + "slice", TrackPoint, Debian/Kali, X11).
Everything below is a place where that shows. **Find your value first, then change only what differs.**

| Thing | Find yours | Where it is hard-coded here | Change when |
| --- | --- | --- | --- |
| Monitor name | `xrandr --query` | `dot/.config/bspwm/bspwmrc` (`eDP-1`), `system/etc/X11/xorg.conf.d/10-monitor.conf` | your internal output is not `eDP-1` |
| Resolution / size | `xrandr`, `xdpyinfo \| grep dimensions` | conky `hud.conf` (`gap_x = 1277` puts the HUD in the right column), `bg.lua`, `clock.conf`; polybar `config.ini` (bar widths/offsets); `scripts/wallpaper/gen_*.py` (1600x900); `modes/*.conf` (`TOP_PAD`, gaps) | any screen that is not 1600x900: scale the HUD x-offset, bar geometry, wallpaper size |
| Text size / DPI | `xrdb -query \| grep dpi`, `xsettingsd.conf` (`Xft/DPI`) | `kitty.conf` (`font_size 16`), `alacritty.toml` (`size = 12`), `modes/*.conf` (`UI_FONT`), xsettingsd DPI written by `mode.sh` | HiDPI or a bigger/smaller panel |
| Network interface | `ip -br link`, `iw dev` | `wlan0` in conky `hud.conf`, `polybar/scripts/mylhost.sh`, `myip.sh`, `dot/.zsh/prompt/ip-detection.zsh`, `dot/.bashrc` | your Wi-Fi/Ethernet is `wlp3s0`, `enp...`, etc. |
| Batteries | `ls /sys/class/power_supply` | conky `hud.conf` POWER section (`BAT0` = INTERNAL, `BAT1` = SLICE), `polybar/scripts/battery_combined.sh` (combines every `BAT*`), `system/etc/tlp.d/01-rip.conf` (charge thresholds per `BAT0`/`BAT1`) | one battery, different names, or no slice: delete the SLICE line, fix names, set your own thresholds |
| CPU temperature / fan | `for f in /sys/class/hwmon/*/name; do echo $f $(cat $f); done` | conky `hud.conf` (`hwmon coretemp`), polybar `[module/temperature]` (sensor by type) | AMD (`k10temp`), other sensor names, no fan |
| Brightness device | `ls /sys/class/backlight` | polybar `[module/backlight]` (card), `power-mode.sh` uses `brightnessctl` | polybar shows nothing for brightness |
| Keyboard backlight | `ls /sys/class/leds \| grep -i kbd` | auto-detected (`*kbd_backlight*`), nothing hard-coded | no such LED: the daemon silently does nothing |
| Touchpad / pointing stick | `xinput list` | `dot/.config/bspwm/start` (`TPPS/2 IBM TrackPoint` accel), `scripts/touchpad.sh`, `system/etc/modprobe.d/psmouse-intertouch.conf` | not a ThinkPad: remove or retarget the device names |
| Graphics / video accel | `lspci -k \| grep -A3 VGA`, `vainfo` | `LIBVA_DRIVER_NAME=iHD` in `bspwmrc` and `system/firefox/user.js` (Intel); picom backend in `picom/picom.conf` | AMD/NVIDIA or a different Intel generation |
| Display manager | `systemctl status display-manager` | `install.sh -full` installs XFCE + LightDM; `-ly` installs ly (white-on-black `system/etc/ly/config.ini`, *bspwm* and *bspwn* sessions, `ly-watchdog.service` for a login that hangs after Xorg starts); `system/etc/ly/` | you already have a login manager you want to keep |
| Window border gap | your terminal background (`alacritty.toml` `background`) | `modes/cockpit.conf`: `BORDER=9`, `DOUBLE_BORDER=1`, `BORDER_GAP_COLOR` (painted by `bspwm/scripts/double-border.py`, needs `python3-xlib`) | you change the terminal colours, or want a plain border (`DOUBLE_BORDER=0`, `BORDER=1`) |
| Lid / power key | `loginctl show-logind`, `ls /etc/acpi/events` | `system/etc/acpi/lid.sh` (locks on lid close), logind handles suspend | no acpid, different lid event name |
| Screen locker | `command -v xlock i3lock slock` | sxhkd `super+x` and the idle lock (`scripts/idle-lock.sh`, started by `bspwm/start`, keeps `xss-lock` alive; it must run inside the login session, so restart it with `bspc wm -r`, not from a tmux shell) call a command named `xlock`; the repo ships `scripts/xlock` (a slock wrapper) | install it (`sudo install -m755 scripts/xlock /usr/local/bin/xlock`) or point those two places at your locker |
| Default apps | `command -v chromium thunar alacritty kitty flameshot` | sxhkd, polybar app buttons, `bspwm/start` (chromium, Thunar, alacritty, kitty, flameshot, firefox-esr, caido) | you use other apps |
| Package names | your package manager | `install/packages.sh` is Debian/Kali (apt) | Arch/Fedora/etc.: translate the package list |
| Absolute home paths | `grep -rn '/home/' dot` | `dot/.zshrc`, `dot/.config/conky/conky.conf`, `dot/.config/gtk-3.0/bookmarks`, `dot/.vim/.netrwhist` | always: replace with `$HOME` or your path |
| Personal tooling | read `dot/.zsh/pentest/`, `dot/.zshrc` | pentest helpers and aliases; polybar LHOST/RHOST widgets write `~/.current_ip`, `~/.current_target` and `export rhost=...` into `~/.zshrc` | you do not want those (remove the two modules from `modules-left` of the right bar in `polybar/config.ini`) |

## Power tools on another laptop
- `power.conf` is per machine. `SERVER_BATTERY_MIN=auto` is 20 for two batteries and 55 for one; set a number if you prefer.
- `SERVER_BATTERY` picks the charge server mode watches: `total`, `lowest` or a battery name. The shipped `auto` watches `BAT1` (the slice) when there are two
  batteries and the only battery otherwise. Check battery health first (`energy_full` vs `energy_full_design` in `/sys/class/power_supply/BAT*`): watching a worn-out battery ends server mode early.
- Keyboard LED level 1 is "minimal" on the ThinkPad (max 2). Check `cat /sys/class/leds/<kbd led>/max_brightness`; some laptops have 3 levels or an ambient-light mode.
- The lid is ignored by a logind inhibitor, which needs systemd-logind and a polkit rule allowing the active session to inhibit (default on Debian/Ubuntu/Fedora/Arch desktops).
- **Compositor**: `PICOM=0` in `power.conf` (shipped) keeps picom off; `PICOM=1` runs it on AC only (fade only, `picom/animations.conf`, GLX backend on Intel).
  Apply with `scripts/power-mode.sh auto --force`. Slow GPU: try `backend = "xrender"` or `PICOM=0`.
- The **battery guard** (`GUARD_*` in `power.conf`) exists because on the original ThinkPad the hand-over from a drained external battery to the internal one
  has cut the power (the internal battery itself works). On a laptop with one healthy battery, Linux's own
  low-battery action already works; keep the guard (it is harmless) or set `GUARD_ENABLED=0`. `GUARD_ACTION=hibernate` only if hibernation with resume is configured.
  `GUARD_WARN_MV` / `GUARD_ACT_MV` (voltage trigger, for packs whose % gauge lies) are set for a **3-cell** pack (11000 / 10850 mV, about 3.67 / 3.62 V per cell, below the flat middle of the discharge curve):
  scale them to the user's cell count (`voltage_min_design` / 3.7 V), or set them to 0. Restart the daemon with `servermode.py restart`, never a plain kill
  (with the lid closed in server mode a kill suspends at once).
- Two-battery ThinkPads: `thinkpad_acpi` exposes `charge_behaviour` = `force-discharge`, but on the original T450 the firmware **rejects it while on battery** (EIO), so the
  discharge order cannot be changed off AC. Test before relying on it: `echo force-discharge > /sys/class/power_supply/BAT0/charge_behaviour` (as root, on battery), then `auto`.
- Run `python3 scripts/tests/test_power.py` after any change to the power scripts.

## Things not tested on other hardware
This repo has only been run on the ThinkPad above. A Dell (or any other laptop) is expected to need the items in the table; verify each one, do not assume.

## Shell (not hardware, but often tuned)

- `dot/.zsh/plugins/fzf.zsh`: Ctrl+F file finder, exact + case-insensitive; quote a term (`'word'`) for whole-word matching.
- `dot/.zsh/config/completion.zsh`: plain zsh completion (menu on Tab, Tab/Shift-Tab cycle it). The as-you-type `zsh-autocomplete` menu is disabled (`_bspwn_autocomplete=0`); it needs `/usr/share/zsh-autocomplete` if you turn it on.
  `config/keybindings.zsh` loads after it, so never rebind `^[[Z` there.

## Slow after resume (CPU stuck at minimum clock)

If the desktop lags after suspend/hibernate and `grep MHz /proc/cpuinfo` shows the minimum clock under load while `scaling_governor` says `performance`,
install `system/usr/lib/systemd/system-sleep/bspwn-cpufreq` (`./install.sh -system` does it). It switches the governor away and back after resume. Harmless on machines without the problem.

## Hibernate button (power menu)

`polybar/scripts/pwmenu.sh` has a Hibernate button (`systemctl hibernate`). It only works if you have a swap area at least as big as your RAM **and** resume is configured
(`cat /sys/power/resume` is not `0:0`, `busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate` says `yes`; on Debian add `resume=` / `RESUME=` and run `update-initramfs -u`). Otherwise remove the button.
