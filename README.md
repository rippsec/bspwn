# bspwn

A bspwm desktop for a ThinkPad T450 running Kali/Debian, with a muted monochrome look and a handful of small custom tools (live theme switcher, keyboard backlight, "server mode" for closing the lid without suspending). Everything is plain config files and small Python/bash scripts.

![desktop](docs/screenshots/desktop-hud.png)

**Full documentation:** the [user manual](docs/BSPWN-manual.md) ([PDF](docs/BSPWN-manual.pdf), with diagrams and a table of contents), a one-page [cheatsheet](docs/BSPWN-cheatsheet.md) ([PDF](docs/BSPWN-cheatsheet.pdf))
and an [interactive manual](docs/interactive.html) (open the file in a browser: clickable bar, key explorer, tiling playground, quiz, recipes).

This README is the front page and the **reference for every custom setting**: [Reading the screen](#reading-the-screen) explains every symbol in the bar and every block of the HUD, and [Settings you can tweak](#settings-you-can-tweak)
lists every custom setting. To make it fit your own computer, see [Adapting it to your machine](#adapting-it-to-your-machine-with-claude-code).

## Contents

[What is in here](#what-is-in-here) · [Install](#install) · [Reading the screen](#reading-the-screen) · [Keys](#everyday-keys) · [Settings you can tweak](#settings-you-can-tweak) ·
[Themes](#themes) · [Terminal colours](#terminal-colours) · [Other pieces](#other-pieces) · [Adapting it / Claude Code](#adapting-it-to-your-machine-with-claude-code) · [Layout](#repo-layout) · [License](#license)

## What is in here

- **Two modes, switched live** (`super+ctrl+u`): *cockpit* (default: monochrome, polybar, conky HUD, tiling) and *undercover* (a Windows 10 look, tint2, floating windows).
- **Terminal palette** (kitty + alacritty) with a contrast checker.
- **Themer**: a small GTK app that previews GTK and icon themes and applies them live, no relogin.
- **Keyboard backlight that follows your typing** and **server mode** (keep running with the lid closed).
- Dotfiles for bspwm, sxhkd, polybar, picom, conky, dunst, rofi, tmux, zsh, nvim, kitty, alacritty and more, with an installer.

## Install

```sh
git clone https://github.com/rippsec/bspwn && cd bspwn
./install.sh --help       # all options; read it first on a machine you care about
./install.sh -config      # only link the configs (also the way to update)
./install.sh -themes      # GTK theme + icons + Qt setup
./install.sh -wallpaper   # personal wallpaper with your user name
./install.sh -full        # everything, see below
```

`-full` installs the packages and fonts, links the configs, sets up themes and Neovim, installs the system files (ACPI lid handler, X11 and a bspwm session entry)
and finally **installs XFCE + LightDM and enables LightDM as your login manager** (reboot, then pick the *bspwm* session). Use the smaller options if you do not want that.

The installer copies the project to `~/.bspwn` and symlinks `~/.config/<app>` to `~/.bspwn/dot/.config/<app>`, so editing either path edits the same file.
It targets Debian/Kali (apt) and was only run on one ThinkPad; for anything else see [Adapting it](#adapting-it-to-your-machine-with-claude-code).

## Reading the screen

Three parts: the **bar** (top), the **HUD** (right) and the **wallpaper** (`scripts/wallpaper/gen_bspwn.py`). `./install.sh -wallpaper` (also in `-full`) makes a personal version with your user name in capitals, saved to `~/.local/share/bspwn/wallpaper.jpg`; delete it to go back to BSPWN.

### The bar, symbol by symbol

![polybar](docs/screenshots/polybar.png)

Three islands plus the launcher (far left) and power button (far right), joined by thin separators. Numbers match the picture.

| # | Symbol | What it shows | Click / scroll |
| --- | --- | --- | --- |
| 1 | Kali logo | **App launcher** | click: full-screen launcher (rofi); click again to close |
| 2 | ten dots | **Desktops** 1-9 and 0. Filled white dot = the desktop you are on, ring with a dot = has windows, faint ring = empty | click a dot to go there |
| 3 | terminal | **Terminal** | left: terminal attached to the `tmux` session (created if missing, same as `super+Return`); right: plain terminal |
| 4 | globe | **Browser** (Brave) | left: open it |
| 5 | folder | **File manager** (Thunar) | left: your home folder; right: Downloads |
| 6 | chip + block | **CPU load** | none. The small block grows with load: dim grey, grey, white, and turns into an *inverted* `!` when it is in alarm (same width, so nothing in the bar shifts) |
| 7 | memory + block | **RAM in use** | none. Same block as above |
| 8 | disk + block | **Root disk fullness** (more blocks = less space left) | none |
| 9 | thermometer + block | **CPU temperature** | none |
| 10 | keyboard | **Modifier keys.** Dim keyboard when idle; while you hold Super, Ctrl, Alt or Shift (or Caps Lock is on) it shows that one key lit with a line above and below. If several are held only the highest priority shows: Super > Ctrl > Alt > Shift > Caps | none |
| 11 | date and time | **Clock** | click: calendar dropdown under the clock |
| 12 | link icon + address | **LHOST**: your address for lab work (a chosen interface or a custom IP) | left: pick an interface or type an IP inline; right or double click: copy. Saved in `~/.current_ip` |
| 13 | crosshair + address | **RHOST**: the target address, `none` when unset | left: set/edit inline; right or double click: copy. Saved in `~/.current_target`, and it **writes `export rhost=...` into `~/.zshrc`** so shells see `$rhost` |
| 14 | server rack | **Server mode** (lid closed = keep running). Dim = off; bright and underlined = on; shows the battery % while on battery | click: toggle (same as `super+ctrl+s`), see [Server mode](#server-mode-lid-closed-laptop-keeps-running) |
| 15 | mask | **Mode switch**: cockpit <-> undercover (Windows look) | click: switch (same as `super+ctrl+u`) |
| 16 | speaker + block | **Volume.** A **red** speaker with lines above and below means muted | scroll: volume up/down (with a notification) |
| 17 | sun/gear + block | **Screen brightness** | scroll: up/down (with a notification) |
| 18 | battery | **Battery, all batteries combined** into one icon (a bolt when charging on AC) | click: notification with each battery and the AC state |
| 19 | microphone | **Mic.** Dim crossed-out mic = muted; **red** lit mic = live (unmuted) | click: mute/unmute |
| 20 | Wi-Fi icon | Click opens a dropdown (`polybar/scripts/wifimenu.sh`, theme `rofi/wifi.rasi`): list of networks with signal and lock, click to connect (asks for the password the first time), click the active one to disconnect, Wi-Fi on/off, advanced settings (`nm-connection-editor`) | click |
| 20 | tray icons | **System tray**, collapsed: the arrow button (right island) opens/closes a drawer (`polybar/scripts/traytoggle.sh`, bar `[bar/tray]`; icon size `tray-size`) with the network applet, clipboard manager and any app that puts an icon there | per app |
| 21 | power symbol | **Power menu** | click: full-screen menu with Lock, Sleep, **Hibernate** (suspend to disk: no battery drain while off; it powers off and on resume the machine boots, asks the disk passphrase, then restores your session, so it looks like a reboot but nothing is lost), Logout, Restart, Shutdown; Esc or a second click closes it |

### The HUD column (right side)

A [conky](https://github.com/brndnmtthws/conky) widget, `dot/.config/conky/hud.conf`. It is a desktop widget, so windows cover it; it is turned off while on battery (the power profile stops conky, and picom if it runs, to save power).

| Block | What it shows |
| --- | --- |
| clock and calendar | time, date and a month calendar with today highlighted |
| **SYSTEM** | host name, kernel, uptime and load average |
| **CPU** | load %, frequency, temperature, a load graph, and the top processes by CPU |
| **MEMORY** | RAM used / total with a bar, and swap |
| **THERMAL** | CPU temperature and fan speed |
| **STORAGE** | root disk used / total with a bar, and read/write rates |
| **NETWORK** | Wi-Fi name and signal, the interface address, received/sent bytes and a traffic graph |
| **POWER** | one bar per battery: **INTERNAL** and **SLICE** (the ThinkPad's second battery) with % and status; the value changes colour at 20% or below |

### Modes

`super+ctrl+u` (or symbol 15) switches the whole desktop live, with no logout: **cockpit** is the monochrome rice described here; **undercover** is a Windows 10 look (theme, icons, tint2 panel, floating windows).
Each mode is a profile in `dot/.config/bspwm/modes/*.conf` (theme names, wallpaper, panel, gaps, borders). The active mode is remembered in `~/.cache/bspwn-mode`.

## Everyday keys

| Keys | Action |
| --- | --- |
| `super+Return` / `super+shift+Return` | terminal (attached to tmux) / plain terminal |
| `super+d` / `super+r` | app menu (jgmenu) / launcher (rofi) |
| `super+Tab`, `alt+Tab` | window overview / switcher (skippy-xd) |
| `super+ctrl+u` | toggle cockpit / undercover mode |
| `super+ctrl+s` | **toggle server mode** |
| `super+x` | lock the screen (it also locks by itself after 5 min idle, turning the screen off once the lock is up, and before suspend) |
| `super+Left/Right`, `super+alt+Left/Right` | previous/next desktop, move window there |
| `super+p` | toggle focus-follows-pointer |
| `super+e` | toggle touchpad |
| `Print`, `super+shift+s` | screenshot (flameshot) |
| `super+Escape`, `alt+shift+Escape` | restart bspwm, reload sxhkd |

**Idle lock: lock first, then screen off.** `bspwm/start` turns X's own screensaver and DPMS timers off (`xset s off`, `xset dpms 0 0 0`) and starts
`scripts/idle-lock.sh`. Its watcher reads the idle time; after 300 s (`IDLE_LOCK`) it runs `xlock`, waits until the lock is on screen, and only then turns the
display off, so waking the screen shows the lock, never the desktop. The script also keeps `xss-lock` running (it locks before suspend) and restarts it if it exits
(log: `journalctl -t idle-lock`). xss-lock has to run inside the login session.
Started from a tmux shell it aborts after each lock ("NoSessionForPID"), so restart it with `super+Escape`, not by hand.

## Settings you can tweak

### Power tools (`power.conf`)

All power settings live in **`~/.config/bspwm/power.conf`** (a symlink to `dot/.config/bspwm/power.conf`). It is plain `KEY=VALUE`, read live: save the file and the change applies
within a few seconds, no restart. The scripts are in `dot/.config/bspwm/scripts/` (`kbd-backlight.py`, `servermode.py`, shared `powerlib.py`) and start from `bspwm/start`.
No root is needed: the keyboard LED is set through logind and the lid is handled with a logind inhibitor lock.

#### Compositor (picom)

| Setting | Shipped | Meaning |
| --- | --- | --- |
| `PICOM` | `0` | `1` = run [picom](https://github.com/yshui/picom) (shadows, fades, transparency) on AC; it is always stopped on battery. `0` = never run it (this ThinkPad). |

`scripts/power-mode.sh` reads it whenever the power source changes or a mode is applied; to apply it at once run `~/.config/bspwm/scripts/power-mode.sh auto --force`.
Without picom, window transparency (e.g. alacritty's `opacity`) and shadows are off.

#### Keyboard backlight

A keypress lights the backlight at the minimal level; it turns off `KBD_IDLE_AC`/`KBD_IDLE_BAT` seconds (default 9) after the last key. Held keys count as typing. A manual off (Fn+Space) stays off until the next keypress, and it stays off while the lid is closed. Keys come from XInput raw events (also seen on the lock screen). Works with any `/sys/class/leds/*kbd_backlight*`; does nothing without one.

| Setting | Shipped | Meaning |
| --- | --- | --- |
| `KBD_AUTO` | `1` | `0` = never touch the keyboard backlight |
| `KBD_IDLE_AC` | `9` | seconds after the last keypress before it turns off, on AC. Use `1` for a quick off, `10` for a longer glow, `0` = never turn off |
| `KBD_IDLE_BAT` | `9` | the same, on battery |
| `KBD_LEVEL` | `1` | level a keypress lights it to (`1` = minimal; `0` = the level it had before) |
| `KBD_WAKE_POINTER` | `0` | `1` = touchpad/mouse input also lights it |

#### Server mode (lid closed, laptop keeps running)

For leaving a laptop on a desk running things you reach remotely (ssh, a remote shell, file transfers, remote-controlled sessions): **closing the lid does not suspend**.
The screen locks and goes dark and the keyboard light turns off, but the system and its connections keep running.

![server mode button](docs/screenshots/polybar-server-mode.png)

- **Turn it on/off**: click the server icon in the bar (14), press `super+ctrl+s`, or run `~/.config/bspwm/scripts/servermode.py on|off|toggle|status`.
- **On AC** it runs until you turn it off. **On battery** it keeps running until the watched charge drops below a threshold, then it turns itself off and the laptop behaves normally
  (it suspends if the lid is closed). Which charge is watched is `SERVER_BATTERY` (shipped `active`: whichever battery is powering the laptop).
- It is **off after every reboot/logout** on purpose (state lives in `$XDG_RUNTIME_DIR`).
- **Safe by design**: the lid is ignored only while the daemon holds an inhibitor lock, which the kernel releases the moment the daemon exits or crashes.
- When server mode ends on a low battery with the lid closed it normally suspends; if the [battery guard](#battery-guard) is keeping the laptop awake it stays up and shuts down cleanly instead.

| Setting | Shipped | Meaning |
| --- | --- | --- |
| `SERVER_BATTERY_MIN` | `auto` | battery % below which server mode ends. `auto` = 20 on laptops with two batteries (ThinkPad with the slice), 55 on single-battery laptops; or a number, e.g. `60` |
| `SERVER_BATTERY` | `active` | which charge is compared with the minimum. `active` = the battery powering the laptop right now; `auto` = the slice (`BAT1`) on a two-battery ThinkPad, the only battery on a one-battery laptop; or `total` (all batteries, the default when unset), `lowest`, or one battery by name (`ls /sys/class/power_supply`). A name that does not exist falls back to `total` |
| `SERVER_TEMP_MAX` | *(commented out)* | uncomment (e.g. `88`) to also end server mode, and suspend, above a temperature in °C. Off by default |
| `SERVER_LOCK` | `1` | lock the screen when the lid closes (the ACPI lid handler usually does it first; this is the fallback) |
| `SERVER_SCREEN_OFF` | `1` | turn the display off while the lid is closed |

Troubleshooting: `servermode.py status`, `systemd-inhibit --list | grep bspwn` (the lock is held while it is on), `journalctl -t bspwn-power` (daemon log).
Wi-Fi power saving should be off for remote access to stay snappy (`iw dev wlan0 get power_save`).
The logic is covered by tests on a fake sysfs: `python3 scripts/tests/test_power.py`.

#### Battery guard

Never lets the battery run out with the laptop on (or asleep). On battery it watches the battery that powers the laptop and:

1. **warns** at 15%, when about 8 minutes are left at the current draw, or when the battery's **voltage** falls to 11.0 V;
2. at 7%, about 4 minutes left or 10.85 V shows a **countdown (30 s, or 5 s when the voltage triggered it), then hibernates**: the session is saved to disk and comes back on the
   next power-on. Plugging in power cancels it;
3. below 30% or 11.0 V **does not suspend** (lid, idle timeout or the power menu): a laptop that runs out of battery *while asleep* just loses power. With the lid closed it locks and
   blanks the screen like server mode and stays awake until it is safe to act.

Why the voltage: a worn battery's percentage can lie. This ThinkPad's external battery read 59% and was empty 15 seconds later (seen during a `tlp recalibrate`), while its voltage
was already down at 10.76 V. The voltage falls steadily before the collapse, so it gives a warning the percentage does not. The values suit 3-cell packs (11.1 V nominal);
the readings are smoothed so a short load spike does not trigger it.

**Two batteries (ThinkPad T450 with an external battery):** the firmware drains the external first, and when it runs *dry* the switch to the internal battery can fail and cut the power,
while pulling the external out with the laptop running is a clean switch. The firmware only lets Linux choose the battery while on AC (`charge_behaviour` = `force-discharge` is rejected on
battery), so the switch cannot be automated. Instead the warnings tell you to **pull the external battery out** (the laptop carries on with the internal one) or plug in.
If the power does cut out, the internal battery can stay locked out afterwards (it boots on AC and dies when AC is unplugged, even with the external removed). For that reason the
internal battery's TLP charge range is 95-100% (`system/etc/tlp.d/01-rip.conf`) instead of a storage range, so it is topped up whenever AC is plugged in.

It uses minutes as well as % because a small or worn battery's percentage is unreliable. It was built for this ThinkPad: when its external battery *runs out*, the laptop has sometimes
cut off instead of switching to the internal one (which works fine on its own, tested), and Linux's own low-battery action never fires because it averages both batteries.

| Setting | Shipped | Meaning |
| --- | --- | --- |
| `GUARD_ENABLED` | `1` | `0` turns the guard off |
| `GUARD_BATTERY` | `active` | battery to watch: `active` = whichever battery is powering the laptop (follows the battery switch); or the `SERVER_BATTERY` values |
| `GUARD_WARN_PCT` / `GUARD_WARN_MIN` | `15` / `8` | warn at this % or with this many minutes left |
| `GUARD_ACT_PCT` / `GUARD_ACT_MIN` | `7` / `4` | start the countdown at this % or minutes left |
| `GUARD_WARN_MV` / `GUARD_ACT_MV` | `11000` / `10850` | warn / start the countdown at this battery voltage in millivolts (`0` = off, the code default). Set them for your pack: about 3.67 / 3.62 V per cell, below the flat middle of the discharge (this external sits at 11.1-11.26 V from 58% to 31% at ~5 W) |
| `GUARD_MV_HOLD` | `6` | the voltage must stay at or below the setting this many seconds before it counts (a load spike sags a worn pack by ~0.4 V for a moment) |
| `GUARD_GRACE_MV` | `5` | countdown in seconds when the voltage triggered it (a worn pack collapses within seconds) |
| `GUARD_ACTION` | `hibernate` | `hibernate` (only if resuming from hibernation is set up on your system; it is here), `poweroff` or `none` (notifications only) |
| `GUARD_SWAP_HINT` | `1` | with two batteries, the warnings suggest pulling the low one out while the other still has charge |
| `GUARD_GRACE` | `30` | seconds of countdown |
| `GUARD_NO_SUSPEND_BELOW` | `30` | on battery below this % (or below `GUARD_WARN_MV`), the laptop does not suspend |

`servermode.py status` shows the guard's state (`ac`, `armed`, `warned`, `countdown`); `journalctl -t bspwn-power` logs what it did.

### Themes

`themer` (installed to `~/.local/bin/themer`, also in the app menu) shows your installed GTK and icon themes, restyles its own window and a sample icon grid as you click, and **Apply** (`Ctrl+Enter`)
makes the choice live: xsettingsd and gsettings (running apps), GTK 2/3/4 settings, Qt (qt5ct/qt6ct icons), rofi, and the active mode profile so a mode switch or `bspc wm -r` keeps it.

![themer](docs/screenshots/themer.png)

```sh
themer                                   # GUI
themer --gtk Adwaita-dark --icons Papirus   # headless
themer --list      # installed themes        themer --current   # what is live
```

A standalone, window-manager-agnostic version (no bspwm specifics, a hooks directory for your own targets) lives at
[rippsec/themer](https://github.com/rippsec/themer).

The default theme here is `Flat-Remix-GTK-Slate-Darkest`, a custom variant generated with the upstream
[flat-remix-gtk](https://github.com/daniruiz/flat-remix-gtk) script and bundled in `dot/theme/themes` (icons: Flat-Remix-Black-Dark in `dot/theme/icons`).
To make your own: `./generate-color-theme.sh Name '#HIGHLIGHT' '#HIGHLIGHT_TEXT'` (needs `make inkscape sassc optipng`), then copy the result to `dot/theme/themes/` and `~/.themes/`.
Modes keep their theme names in `dot/.config/bspwm/modes/*.conf`.

### Terminal colours

![terminals](docs/screenshots/terminals.png)

`dot/.config/kitty/cockpit.conf` and the `[colors]` block of `dot/.config/alacritty/alacritty.toml` hold the same palette (alacritty reloads by itself; kitty: `ctrl+shift+f5`).
Lifted background, soft off-white text, no deep blue; every colour differs by **lightness as well as hue**, so a symlink (cyan) and a directory (blue) are never confused.

```sh
python3 scripts/palette_check.py         # contrast + colour-difference report; exit 1 if a target is missed
```

It checks text contrast, that every pair of hues is far enough apart (CIEDE2000 ≥ 20, ≥ 14 at 60% chroma) and that bright variants differ from normal ones.
Edit both files together, re-run the checker, and look at it in a real terminal. `lsd` (the `ls` alias) is mapped onto the palette in `dot/.config/lsd/`.

## Shell: fzf and completion

`~/.zshrc` is tiny: it sources `dot/.zsh/init.zsh`, which loads `config/`, `prompt/`, `plugins/`, `aliases/`, `functions/`, `pentest/`, then `exports.zsh` and `theme.zsh` in that fixed order
(documented in the file). Put machine-specific extras in `~/.zshrc.local` (not in git); a new plugin, alias file or function file is picked up by dropping a `*.zsh` into its folder.

- **`Ctrl+F`** fuzzy-finds any file on the system and pastes it (`dot/.zsh/plugins/fzf.zsh`). Matching is exact and case-insensitive, so `claude` is a plain substring.
  For a whole word, quote it: `'claude'` matches `claude-code` and `/x/claude/y` but not `claudette`. Also `!word` (exclude), `^word`, `word$`, and space = AND.
- **Completion menu** (`zsh-autocomplete`): Up/Down and Tab / Shift-Tab cycle through the options (Tab next, Shift-Tab previous, nothing is deleted; Shift-Tab used to be `undo`); **Left/Right still move the text cursor** (they close the menu) so you can edit a recalled command
  (`dot/.zsh/config/completion.zsh`).

## Other pieces

- **Wallpapers**: generated with Pillow by `scripts/wallpaper/gen_*.py` into `assets/wallpaper/`; the active one is set in `modes/cockpit.conf` and `bspwm/start`.
- **system/**: root-level files (ACPI lid handler, X11, tlp, display manager) installed by `./install.sh -system`.

## Adapting it to your machine (with Claude Code)

This setup was built on one laptop, so some values are tied to it: screen size, network and battery names, the ThinkPad TrackPoint and charge-threshold settings, Intel video acceleration, Debian package names.
The repo ships a [Claude Code](https://claude.com/claude-code) skill that knows where all of that lives and how to change it safely:

```sh
cd ~/.bspwn        # or wherever you cloned it
claude             # Claude Code picks up .claude/skills/adapt-bspwn automatically
> adapt this setup to my laptop        # or: "my battery is called BAT0 only", "I have a 4K screen", "port it to Arch"
```

The repo also has a [`CLAUDE.md`](CLAUDE.md) at its root: Claude Code reads it automatically and learns how this desktop is organised, how to reload each part and what it must not touch,
so you can ask it for any change ("add a shortcut", "change the browser button", "make the bar bigger"). The skill ([`.claude/skills/adapt-bspwn/SKILL.md`](.claude/skills/adapt-bspwn/SKILL.md)) makes Claude inspect your hardware first (read-only), show you a plan, change only what differs, and verify with the tests and the palette checker.
It will not run the full installer, touch system files or lock your screen without asking. The table of machine-specific places is in
[`references/hardware-map.md`](.claude/skills/adapt-bspwn/references/hardware-map.md), which is also a good checklist to follow by hand.
Only the ThinkPad has been tested so far: expect other laptops (a Dell, say) to need some of the items in that table, and verify each one instead of assuming.

## Repo layout

```
dot/.config/<app>/      app configs (symlinked into ~/.config)      dot/theme/     bundled GTK theme + icons
dot/.config/bspwm/      bspwmrc, start (autostart), modes/, power.conf, scripts/ (mode.sh, power tools, ...)
scripts/                themer/, palette_check.py, wallpaper/, tests/
install.sh, install/    installer (packages, fonts, themes, configs, ...)       system/   root-level files
.claude/skills/         adapt-bspwn: the Claude Code skill for adapting this setup to another machine
docs/                   manual (md+pdf), cheatsheet, interactive.html, screenshots/, diagrams/; sources in docs/src/ (built by scripts/docs/build.py)
CLAUDE.md, NOTICE.md    instructions for Claude Code; authorship and third-party licences
```

## License

Code and configuration: **GPL-2.0-only**, see [LICENSE](LICENSE). Copyright (c) 2025-2026 **rippsec ([github.com/rippsec](https://github.com/rippsec)) and contributors**.
Documentation (`docs/`): **CC BY-SA 4.0**. You are free to use, change and share this, but you must keep the copyright and licence notices, publish your changes under the same licence and not present
it as your own work. [NOTICE.md](NOTICE.md) has the details, the authorship record and the licences of the bundled third-party themes, icons and fonts. The public git history is the proof of who made what and when. Official channels of the author: [GitHub](https://github.com/rippsec), [LinkedIn](https://www.linkedin.com/in/rippsec), [Hack The Box](https://profile.hackthebox.com/profile/019c8c0d-954d-73ef-a0ea-f6291b8da8a4); nothing else is official.

## Dell Precision 7780 (this branch)

This branch runs the same desktop on a Dell Precision 7780 (panel driven at 1600x900, one battery,
I2C-HID touchpad, Dell keyboard backlight). What differs from the ThinkPad on `main`:

- **Compositor**: `PICOM=1` in `bspwm/power.conf` (picom on AC, off on battery). The ThinkPad runs without it.
- **Lock screen**: the animated `xlock` and plain `xss-lock -- xlock` stay; the ThinkPad's static BSOD,
  `xss-lock --transfer-sleep-lock` and `idle-lock.sh` supervisor were workarounds for bugs on that machine only.
  Idle locking here is still X's own timer (`xset s 300`, display off at 310 s) driving `xss-lock`; main switched
  those timers off because `idle-lock.sh` does the locking there.
- **Battery guard**: one healthy battery whose % gauge is reliable, so the voltage trigger and the
  pull-the-external-battery hint are off; the guard works on % and minutes left.
- **Charge thresholds** (`system/etc/tlp.d/01-rip.conf`): 85/90 on the single Dell battery.
- **Touchpad**: `touchpad.sh` also finds the Dell pad and resets it by rebinding `i2c_hid_acpi`.
- **Conky HUD**: GPU section, CPU/NVMe/RAM temperatures and both Dell fans (`dell_smm`), one battery.
- **Notifications never show over the lock screen**: `xlock` pauses every running dunst on the bus it actually
  listens on, and stops stray dunsts on autolaunched buses. Those came from needrestart (after `apt`), whose
  notify-send hook did not export the session bus address; `install.sh -system` replaces that hook with a fixed
  copy via `dpkg-divert` (`system/etc/needrestart/notify.d/400-notify-send`). Undo:
  `sudo rm /etc/needrestart/notify.d/400-notify-send && sudo dpkg-divert --package bspwn --rename --remove /etc/needrestart/notify.d/400-notify-send`.
- **Ollama starts on demand, not at boot** (`sudo systemctl start ollama` when you need it). Its startup GPU probe
  deadlocked the NVIDIA 550 driver (`nv_shutdown_adapter` waiting on an ACPI notify handler): the stuck process
  blocked every suspend, and with the lid closed logind retried 108 times in 38 minutes, running hot. Only a reboot
  clears that state.
- **OnlyOffice runs on the Intel GPU only** (`system/bin/onlyoffice-desktopeditors`, plus a per-user menu entry
  that calls it). Its Chromium GPU process probes every GL/Vulkan driver at start; with the NVIDIA driver wedged
  that probe hung and the window stayed blank white (from rofi and from the terminal).
- **Suspend failsafe**: if suspend fails 3 times within 5 minutes with the lid still closed, the laptop powers off
  cleanly (forced after 4 minutes if a stuck process blocks the shutdown). `systemd-suspend.service` runs
  `/usr/local/sbin/bspwn-suspend-failsafe` on failure; its log is `journalctl -t bspwn-power`.

### Antialiasing de fuentes

El suavizado (antialiasing) de las fuentes lo controla **fontconfig**, no la
terminal. El archivo es:

```
dot/.config/fontconfig/fonts.conf   ->   ~/.config/fontconfig/fonts.conf
```

Tiene dos bloques de render:

1. **Global** (`<match target="font">` sin `<test>`): antialias activado,
   `hintslight`, subpíxel `rgb`. Aplica a todas las apps.
2. **Solo Alacritty** (filtrado por `prgname = alacritty`): fuerza
   `antialias = false` + `hintfull` para texto "pixelado"/nítido.
   **Viene desactivado** (comentado).

#### Activar/desactivar el antialias en Alacritty

- **Con antialias (por defecto):** el bloque de Alacritty debe estar comentado,
  es decir, envuelto entre las dos líneas marcadas `NO-AA-ALACRITTY`.
- **Sin antialias (texto nítido):** borra las dos líneas marcadas
  `NO-AA-ALACRITTY` para que el bloque quede activo.

Después de cualquier cambio:

```sh
fc-cache -f          # refresca la caché de fontconfig
# cierra y vuelve a abrir Alacritty (no basta con recargar su config)
```

#### Aplicarlo a otras apps

Dentro del `<test name="prgname">` puedes añadir más programas, uno por línea:

```xml
<test name="prgname" compare="eq">
  <string>alacritty</string>
  <string>polybar</string>
  <string>conky</string>
</test>
```

Para cambiar el antialias de **todo** el sistema edita el bloque global
(`<bool>true</bool>` → `<bool>false</bool>` en `antialias`).

#### Comprobar qué se está aplicando

```sh
fc-match -v 'BlexMono Nerd Font Mono:prgname=alacritty' | grep -E 'antialias|hintstyle'
```

`antialias: True` = suavizado activo; `False` = desactivado.
`xmllint --noout ~/.config/fontconfig/fonts.conf` valida que el XML no esté roto.

### Tema de arranque (GRUB + Plymouth)

Tema GRUB monocromo estilo terminal ASCII con el sigilo 四, en
`system/boot/grub/themes/bspwn/` (generado por `scripts/grub/gen_theme.py`;
edita el script, no los archivos generados).

```sh
python3 scripts/grub/gen_theme.py   # regenerar el tema
./scripts/grub/preview.sh           # previsualizar: GRUB real en una ventana QEMU
./install.sh -boot                  # instalar + activar el enforcer
```

**Sobrevive a las actualizaciones:** `/etc/default/grub.d/zz-bspwn.cfg` se lee
después de `kali-themes.cfg`, y el hook de apt
`/etc/apt/apt.conf.d/99-enforce-boot-theme` ejecuta
`/usr/local/sbin/enforce-boot-theme` tras cada `apt`: si `grub.cfg` ya no usa el
tema bspwn ejecuta `update-grub`, y si Plymouth cambió de tema (o un initramfs
nuevo no lo incluye) lo reaplica.

```sh
sudo enforce-boot-theme status            # qué está fijado / activo
sudo enforce-boot-theme plymouth <tema>   # fijar otro tema de Plymouth
```

Los temas de Plymouth se copian a `/usr/share/plymouth/themes/<tema>/` antes de
fijarlos (p. ej. de github.com/adi1090x/plymouth-themes).
