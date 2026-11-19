# Theme

`themes/Flat-Remix-GTK-Slate-Darkest` is a custom Flat-Remix GTK variant, installed by `install/themes.sh`.
Regenerate it from https://github.com/daniruiz/flat-remix-gtk (needs make, inkscape, sassc, optipng):

    ./generate-color-theme.sh Slate '#26272C' '#f2efe9'   # highlight, highlight text

Icons (Flat-Remix-Black-Dark) are bundled in `icons/` (stock upstream copy from https://github.com/daniruiz/flat-remix; the installer re-downloads it only if missing).

## Switching themes live

`themer` (scripts/themer/themer.py, installed to `~/.local/bin/themer`) is a GTK app that previews GTK and icon
themes in its own window and applies the choice live, without relogin, to xsettingsd, gsettings, GTK 2/3/4,
Qt (qt5ct/qt6ct), rofi and the active bspwm mode profile. Headless: `themer --gtk NAME --icons NAME`, `themer --list`.
