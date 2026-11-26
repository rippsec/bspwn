# Run by LightDM's "Default Xsession" (Debian Xsession): bspwn session launcher.
# bspwm in cockpit mode, xfwm4 (Windows-10 window frames) in undercover mode, switched without logging out.
# See ~/.config/bspwm/scripts/session.sh
export XCURSOR_THEME=Adwaita
export XCURSOR_SIZE=32
exec "$HOME/.config/bspwm/scripts/session.sh"
