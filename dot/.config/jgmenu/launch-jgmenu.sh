#!/usr/bin/env bash
# Launch jgmenu (for polybar / Super+D). Ensures menu opens top-left below bar.
# Remove stale lockfile if no jgmenu process is running (avoids "jams" after crash).
LOCKFILE="${HOME}/.jgmenu-lockfile"
if [[ -f "$LOCKFILE" ]]; then
  if ! pgrep -x jgmenu >/dev/null; then
    rm -f "$LOCKFILE"
  fi
fi
exec jgmenu run
