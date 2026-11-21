---
name: adapt-bspwn
description: Adapt this bspwm desktop (the "bspwn" dotfiles repo) to a different machine - another laptop or desktop, screen size, batteries, keyboard backlight, network card, distro - and keep it working. Use when the user wants to install, port, tune or debug this setup on their own hardware, change its themes/palette/power settings, or understand what a part of it does.
---

# Adapt this bspwm setup to the user's machine

This repo was built on one ThinkPad T450 (1600x900, Intel graphics, two batteries, Debian/Kali, X11). Many values are hardware- or user-specific.
Your job: discover what the user's machine has, change only what differs, verify, and report. The user-facing manual is `README.md`
(what each bar symbol does, every `power.conf` setting). The exact list of hard-coded places is `references/hardware-map.md`: **read it first, then open only the files it points to.**

## Rules
1. **Discover read-only first**, then show the user a short plan (files you will change and why) before editing.
2. **Never run `./install.sh -full` without the user's explicit OK.** It installs packages, system files and **XFCE + LightDM as the login manager**.
   Prefer `-config` (symlink configs), `-themes`, `-fonts`, or run pieces by hand. Back up existing configs first (`./install.sh -backup`).
3. **System files need confirmation** (`/etc/*`, PAM, display manager, sudo installs). Keep a `.bak` next to anything you replace and say how to undo it.
4. **Do not lock the screen to test.** Locker commands really lock the session. Verify with unit tests, `status` commands and screenshots instead.
5. **Keep the repo public-safe**: never commit IP addresses, Wi-Fi names, hostnames, e-mail or tokens. Screenshots must be redacted (the bar and HUD show the IP and SSID).
6. **Publishing**: the maintainer of this repo has given standing permission to **commit and push every completed change** (code, configs, docs) to GitHub
   without asking again. If you are working for someone else on their own clone, follow their wishes instead (default: commit/push only when asked).
   Either way: `git add` only the files you changed (never unrelated diffs the user left), scan the staged diff for secrets first, and never force-push.
7. Be honest about what you could not test (a lid-close, another laptop's keyboard LED, a different distro).

## Workflow
1. **Inspect the machine** with the commands in the "Find yours" column of `references/hardware-map.md` (screen, interfaces, batteries, sensors, backlights, input devices, GPU, login manager, locker, package manager).
2. **Map the differences**: for each row, compare with what the repo assumes. Present only the rows that differ.
3. **Make minimal edits**, grouped by area:
   - *Screen*: wallpaper generators (`scripts/wallpaper/gen_*.py` size), conky HUD x-offset, polybar bar geometry, `TOP_PAD`/gaps in `dot/.config/bspwm/modes/*.conf`, terminal font sizes.
   - *Hardware names*: `wlan0`, `BAT0/BAT1`, `coretemp`, backlight card, touchpad/trackpoint device names, `eDP-1`, `LIBVA_DRIVER_NAME`.
   - *Power*: `dot/.config/bspwm/power.conf` (see README, "Power tools"); delete the slice/second-battery lines if there is only one battery.
   - *Distro*: translate `install/packages.sh` to the user's package manager.
   - *Personal bits*: replace `/home/<original user>` with `$HOME`; remove the LHOST/RHOST widgets and `dot/.zsh/pentest/` if the user does not want them.
   - *Apps*: change the default browser/file manager/terminal in sxhkd, polybar app buttons and `bspwm/start`.
4. **Apply live** where possible and look at it: `bspc wm -r`, `pkill -USR1 -x sxhkd`, `~/.config/polybar/launch.sh`, `pkill -HUP -x xsettingsd`, `~/.config/bspwm/scripts/mode.sh apply`.
   Screenshot to review: `import -window root /tmp/s.png` (a solid colour means the screen is locked or another VT is active; ask the user to unlock).
5. **Verify**:
   - `python3 scripts/tests/test_power.py` (power tools, fake sysfs, no hardware touched)
   - `python3 scripts/palette_check.py` (terminal palette legibility and colour separation)
   - `~/.config/bspwm/scripts/servermode.py status`, `systemd-inhibit --list | grep bspwn`, `journalctl -t bspwn-power`
6. **Report**: what you changed, what you verified, what still needs the user (e.g. "close the lid once to test server mode").

## How the pieces fit (enough to navigate)
- `dot/.config/<app>/` is symlinked into `~/.config/<app>`. `bspwm/start` is the autostart list; `bspwm/modes/*.conf` are **profiles** (GTK/icon theme, wallpaper, panel, gaps)
  applied live by `bspwm/scripts/mode.sh` (cockpit = default monochrome, undercover = Windows-10 look). `mode.sh apply` rewrites `xsettingsd.conf` from the active profile, so any theme change
  must also update the profile; the `themer` tool (`scripts/themer/`) does that.
- Power tools (`bspwm/scripts/kbd-backlight.py`, `servermode.py`, `powerlib.py`, settings in `power.conf`) are single-instance daemons started from `bspwm/start`. Server mode keeps the machine awake
  with the lid closed through a logind inhibitor lock that disappears if the daemon dies. Keyboard backlight lights on a keypress and turns off after `KBD_IDLE_AC/BAT` seconds.
- Terminal palette: `kitty/cockpit.conf` and the `[colors]` block of `alacritty/alacritty.toml` are the same palette, checked by `scripts/palette_check.py`.
  If you change colours, keep every hue pair far apart (CIEDE2000 >= 20) and re-run the checker.
- Colours that are not from the terminal palette (polybar, conky, rofi, dunst, borders) use a separate base `#111214`.

## Pitfalls seen while building this
- `pkill -f PATTERN` can match your own shell command line; anchor the pattern or kill by PID.
- Do not blanket-delete `__pycache__`: one `.pyc` under `dot/.config/ranger/plugins/` is tracked in git.
- Some shells alias `ls`/`cat`/`rm` (lsd/bat/verbose rm); use `command cat` or python for exact bytes.
- Tools that edit tracked files (the theme switcher) leave `git status` diffs the user may not want committed; stage only your own files.
- Replace files that a running bash script is executing by writing a new file and `mv`-ing it over, not by editing in place.
- Hot-reload: `power.conf` is re-read every few seconds; terminals: alacritty reloads itself, kitty needs `ctrl+shift+f5`.
