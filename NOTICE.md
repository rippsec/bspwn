# Notice, authorship and licences

## Who made this

**bspwn** (the bspwm desktop in this repository) is the work of **rippsec** (GitHub: [rippsec](https://github.com/rippsec)) **and contributors**, copyright (c) 2025-2026.
The project's history, with every author and date, is the public git log of <https://github.com/rippsec/bspwn>; that log is the record of who wrote what and when.

## Official channels

The author works under the handle **rippsec** only. The official places are:

- GitHub: <https://github.com/rippsec>
- LinkedIn: <https://www.linkedin.com/in/rippsec>
- Hack The Box: <https://profile.hackthebox.com/profile/019c8c0d-954d-73ef-a0ea-f6291b8da8a4>

Any other account, site or message that claims to be the author or to speak for this project, including accounts with similar names, is **not** official.

## Licence of the code and configuration

The code, scripts and configuration files are licensed under the **GNU General Public License, version 2 (GPL-2.0-only)**: see [LICENSE](LICENSE).
Each script written for this project carries `SPDX-License-Identifier: GPL-2.0-only` and a copyright line in its header.

What the licence means for you, in short:

- You may use, study, change and share it, including selling copies, for any purpose.
- If you distribute it (changed or not) you must **keep the copyright and licence notices**, include the licence text, and offer the source.
- If you distribute a modified version it must be under the **same licence (GPL-2.0)**. You cannot make it closed source or relicense it.
- You must **say what you changed** (git history does this) and **must not claim the original work as your own**: authorship notices stay.
- There is no warranty. Scripts here touch power, lid and lock-screen behaviour; read them before running them on a machine you care about.

## Licence of the documentation

The manual, the cheatsheet, the interactive page, the diagrams and the screenshots under `docs/` (and `docs/src/`) are licensed
**Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)**, <https://creativecommons.org/licenses/by-sa/4.0/>.
Credit: "bspwn by rippsec and contributors, https://github.com/rippsec/bspwn". Share-alike: derivatives stay CC BY-SA.

## Third-party components (keep their own licences)

These files are *bundled for convenience* (mere aggregation: they are separate works, not combined into the GPL-2.0 code) and remain under their authors' licences.

| Component | Where | Author / source | Licence |
| --- | --- | --- | --- |
| Flat-Remix GTK theme (custom Slate-Darkest variant generated with its script) | `dot/theme/themes/` | Daniel Ruiz de Alegría, <https://github.com/daniruiz/flat-remix-gtk> | GPL-3.0 |
| Flat-Remix icon theme (Black-Dark variant) | `dot/theme/icons/` | Daniel Ruiz de Alegría, <https://github.com/daniruiz/flat-remix> | GPL-3.0 |
| libvibrant 1.1.1 (unmodified upstream source, commit `bc0d93f`) | `libvibrant/` | Sefa Eyeoglu, <https://github.com/libvibrant/libvibrant> | GPL-3.0-or-later (its own `LICENSE` and `NOTICE`) |
| Atkinson Hyperlegible Mono font | `assets/fonts/AtkinsonHyperlegibleMono/` | Braille Institute of America, Inc. and contributors | SIL Open Font License 1.1 (`OFL.txt` there) |
| `hackthebox.vim` colour scheme | `dot/.vim/colors/` | audibleblink, based on silofy/hackthebox and joshdick/onedark.vim | MIT |
| `iceberg.vim` colour scheme | `dot/.vim/colors/` | cocopon | MIT |
| ly display manager configuration and translations | `system/etc/ly/` | derived from <https://github.com/fairyglade/ly> | WTFPL (upstream) |

Programs this setup *uses* but does not ship (bspwm, sxhkd, polybar, conky, rofi, tmux, picom, i3lock-color, alacritty, kitty, ...) are installed from your distribution under their own licences.
If you own a component listed above and want its entry changed or removed, open an issue.

## Using the project name

"bspwn" and the look of this desktop are the project's identity. Forks are welcome and encouraged; please name them differently or say clearly that they are a fork of bspwn by rip.
