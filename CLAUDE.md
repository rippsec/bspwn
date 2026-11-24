# CLAUDE.md: how to work on the bspwn desktop

This repository **is** a Linux desktop environment (bspwm + sxhkd + polybar + tmux + zsh + themes + small power/lock tools), cloned to `~/.bspwn`.
You are probably here because the user wants to **change, extend, repair or port** it. Read this file first, then open only the files the task touches.
Do not re-read the whole repo. The human manual is `docs/BSPWN-manual.md` (chapter 12 is the "how to change X" cookbook); the one-page keys are in `docs/BSPWN-cheatsheet.md`.
For porting to other hardware use the skill `.claude/skills/adapt-bspwn/` and its `references/hardware-map.md`.

## Ground rules (follow these)

1. **Inspect before you edit.** Read the file, check the live state (`bspc query -D`, `pgrep -a polybar`, `git status`), then change the smallest thing that does the job.
2. **Apply changes live and look at them.** Reload only the affected piece (table below) and review a screenshot (`import -window root /tmp/s.png`; a solid colour means the screen is locked or another VT is active: stop and tell the user).
3. **Never run `xlock` / i3lock to test.** It really locks the session. Verify with logs (`journalctl -t xlock`, `-t idle-lock`, `-t bspwn-power`), `status` commands and the unit tests.
4. **Ask before**: `./install.sh -full` (installs packages, system files, XFCE + LightDM as login manager), anything in `/etc` or `/usr/local` (keep a `.bak`, explain how to undo), PAM, the display manager, sudo installs, force-push, deleting user data.
5. **Do not kill your own shell:** `pkill -f PATTERN` can match your command line. Use anchored patterns (`pkill -x name`) or PIDs.
6. **Keep the repo public-safe.** Never commit IP addresses, Wi-Fi names, host names, e-mail, tokens, or screenshots that show the bar/HUD with them (redact first). Scan the staged diff before every push. See "Privacy and opsec" below.
7. **`git add` only your own files**; the user may have unrelated edits in the tree (theme files, `.netrwhist`). Normal commits and pushes only, never `--force`. Follow the commit trailer rules of your session.
8. **Update the docs in the same commit** (see "Documentation" below) and report outcomes honestly, including what you could not test.
9. **Respect authorship and the licence.** Code is GPL-2.0-only, docs CC BY-SA 4.0 (see `NOTICE.md`). Keep the SPDX/copyright header in files you edit, add it to new scripts, and never remove authorship notices.

## Privacy and opsec (strict)

This repo is public. Nothing in it, or in its history, may identify or describe the person who maintains or uses it.

- **Never write** in files, docs, comments, screenshots, commit messages, PRs or issues: health conditions, disabilities or medical details, real name, age, location, employer, schedule, devices other than the generic hardware model, accounts, handles other than the project name, or the reasons behind personal preferences. If a setting exists "because of" a person's condition or situation, document only the technical fact (the value and what it does).
- **Describe, do not explain the user.** Say what a colour, font size or option does, never who it was tuned for. Keep docs technical, brief and neutral.
- **Screenshots:** use an empty desktop and redact addresses, SSIDs, host names and user names; close messengers, mail and other personal apps so no tray icon, notification or window title shows (see "Documentation").
- **Commit messages:** short and generic (`update of documentation`, or the project's own tag). Never name personal details or what was removed.
- **When adapting this setup for someone else**, apply the same rules to their data: keep it in untracked local files (`~/.zshrc.local`, `power.conf` overrides), never in the repo.
- **If personal data slips in**: stop, tell the user, remove it from the tree, and ask before rewriting history (backup first, force-push only with their explicit approval).
- Do not copy anything from private notes, memory files or other private repos into this one.

## Layout in one screen

| Path | What |
| --- | --- |
| `dot/.config/<app>/` | app configs. `~/.config/<app>` is a **symlink** into here (bspwm, sxhkd, polybar, conky, rofi, dunst, picom, kitty, alacritty, lsd, nvim, ...) |
| `dot/.config/bspwm/` | `bspwmrc` (env, rules, colours), `start` (autostart `process_list`), `power.conf`, `modes/*.conf`, `scripts/` |
| `dot/.config/sxhkd/sxhkdrc` | **every desktop shortcut** |
| `dot/.config/polybar/config.ini` | the bar (`launch.sh` restarts it; `scripts/` has helper scripts) |
| `dot/.tmux.conf`, `dot/.zsh/` | tmux and the shell. `~/.zshrc` is tiny and sources `dot/.zsh/init.zsh`, which loads `config/ prompt/ plugins/ aliases/ functions/ pentest/` in that order (then `exports.zsh`, `theme.zsh`, `~/.zshrc.local`); add a plugin/function/alias as a new `*.zsh` file in the right folder. Machine-specific shell bits go in `~/.zshrc.local` (not in git). The polybar LHOST/RHOST widgets rewrite the `lhost`/`rhost` lines of `~/.zshrc`: keep them there |
| `dot/theme/` | bundled GTK theme and icons |
| `scripts/` | `themer/` (theme GUI), `palette_check.py`, `wallpaper/gen_*.py`, `tests/test_power.py`, `docs/` (documentation builder) |
| `system/` | root-level files (acpi, ly, X11, tlp, `bin/xlock*`), installed only by `install.sh -system` |
| `install.sh`, `install/` | installer |
| `docs/` | generated manual (md+pdf), cheatsheet, `interactive.html`, `screenshots/`, `diagrams/`; sources in `docs/src/` |

## How a session works (mental model)

`ly` -> Xorg on vt2 -> `bspwmrc` -> `bspwm/start` (restarts the helper processes, starts the power daemons and `idle-lock.sh`) -> `scripts/mode.sh apply` (reads the active
**mode profile** `modes/<mode>.conf`, sets GTK/icons/cursor/wallpaper/gaps/panel). `power-mode.sh` starts conky (and picom only if `PICOM=1` in `power.conf`).
Keys: **sxhkd** reads `sxhkdrc` and runs `bspc ...` (window actions), scripts, or apps. Modes: *cockpit* (monochrome, polybar, tiling) and *undercover* (Windows-10 look, tint2, floating); `Super+Ctrl+u` toggles.
**Gotcha:** `mode.sh apply` regenerates `~/.config/xsettingsd/xsettingsd.conf` from the profile, so any appearance change must also go into the active profile (themer does this) or it is undone.

## Where to change things and how to reload

| Change | Edit | Reload |
| --- | --- | --- |
| a shortcut | `sxhkd/sxhkdrc` | `pkill -USR1 -x sxhkd` |
| gaps, borders, window rules, desktops | `bspwm/bspwmrc`, `modes/*.conf` | `bspc wm -r` or `scripts/mode.sh apply` |
| autostart | `process_list` in `bspwm/start` | `bspc wm -r` |
| the bar | `polybar/config.ini` | `~/.config/polybar/launch.sh` |
| HUD | `conky/hud.conf`, `hud.lua` | restart conky (`pkill -x conky; conky -q -c ~/.config/conky/hud.conf &`) |
| GTK / icons | `themer --gtk NAME --icons NAME` | automatic (`pkill -HUP -x xsettingsd`) |
| terminal colours | `kitty/cockpit.conf` **and** `alacritty/alacritty.toml`, then `python3 scripts/palette_check.py` | alacritty auto; kitty `ctrl+shift+f5` |
| tmux | `dot/.tmux.conf` | `tmux source-file ~/.tmux.conf` |
| power, keyboard light, server mode | `bspwm/power.conf` (read live) | `scripts/power-mode.sh auto --force` for picom/conky |
| idle lock time | `IDLE_LOCK` in `scripts/idle-lock.sh` | `bspc wm -r` |

## Format traps (these have cost time before)

- **sxhkd:** a capital letter in a key means **Shift** (`super + B` is `super+shift+b`). `{a,b}` and `{1-9}` expand into several hotkeys. The command is the **indented** line below. Duplicate combinations exist; search the file before adding one (`grep -n "super + p" sxhkdrc`).
- **polybar:** icons are **real glyph characters** in the file. Polybar does not understand `\u{f059f}`; write them with Python: `python3 -c "print(chr(0xf059f))"`. Icon font: *Symbols Nerd Font Mono*. The bar is several processes (`launcher left center right power`) started by `launch.sh`.
- **tmux:** `bind-key -n M-x` = Alt+x without the prefix; `bind x` = prefix (`Ctrl+b`) then x. The prompt line is styled by `message-style` and `message-format`.
- **Shell:** `ls` = lsd, `cat` = batcat, `rm` is verbose: use `command cat`; in scripts use absolute paths. The Bash tool resets cwd each call.
- **zsh change check:** snapshot `alias`, `functions`, `bindkey`, `env` of `zsh -i` before and after, and diff them (that is how the refactor was verified).
- Never blanket-delete `__pycache__`: one `.pyc` under `dot/.config/ranger/plugins/` is tracked.
- `/home/<user>` must not be hard-coded in new files: use `$HOME` / `~`.

## Documentation (update it every time behaviour changes)

- **README.md** is the public front page and the full `power.conf` reference: update it when behaviour or a setting changes.
- **Shortcuts** live in one place for the docs: `scripts/docs/keys.py`. After changing `sxhkdrc` or `dot/.tmux.conf`, edit `keys.py`, then run:
  ```sh
  python3 scripts/docs/build.py --check   # reports keys bound but undocumented (or the reverse)
  python3 scripts/docs/build.py           # rebuilds docs/*.md, *.pdf, interactive.html, diagrams
  ```
  Never hand-edit the generated files (`docs/BSPWN-*.md|pdf`, `docs/interactive.html`, `docs/diagrams/*.svg`). Edit `docs/src/manual.md`, `docs/src/interactive.template.html`, `docs/diagrams/*.dot`.
  Needs `python3-markdown`, `weasyprint`, `graphviz`.
- Screenshots for docs: use an **empty desktop** (`bspc desktop -f 5`), redact the polybar address, the HUD SSID and wlan0 IP, **view the image before committing**, then go back (`bspc desktop -f 1`).

## Verification menu

`python3 scripts/tests/test_power.py` (power tools on a fake sysfs, no hardware touched) · `python3 scripts/palette_check.py` · `bash -n script.sh` · `python3 -c "import ast;ast.parse(open('f.py').read())"` ·
`~/.config/bspwm/scripts/servermode.py status` · `python3 scripts/docs/build.py --check`.

## Things to leave alone unless asked

The lock screen (`system/bin/xlock*`, PAM), the login manager setup, `libvibrant/` (vendored upstream source, unmodified), wallpaper art, and any `*.bak` files. The voice assistant that used to live in `jarvis/` was removed from this repository and is a separate project.
