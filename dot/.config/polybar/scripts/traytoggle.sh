#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Show/hide the systray drawer (polybar bar "tray"). Usage: traytoggle.sh [toggle|show|hide]
act=${1:-toggle}
pid=$(pgrep -f 'polybar -q -r tray ' | head -1)
[ -n "$pid" ] && polybar-msg -p "$pid" cmd "$act" >/dev/null 2>&1
