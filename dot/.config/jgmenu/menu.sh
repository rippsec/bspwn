#!/bin/bash
# Combined jgmenu: Kali MITRE tree (lx) + All Applications submenu

# ── 1. Get Kali lx output ────────────────────────────────────────────────────
lx_output=$(jgmenu_run lx 2>/dev/null)

# Find line number of the first ^tag( — that's where root items end
first_tag=$(echo "$lx_output" | grep -nm1 '\^tag(' | cut -d: -f1)

if [[ -n "$first_tag" ]]; then
    # Print root items, then inject "All Applications" before submenus start
    echo "$lx_output" | head -n $((first_tag - 1))
    echo "---"
    echo "All Applications,^checkout(jgmenu-all-apps),applications-other"
    echo "$lx_output" | tail -n +"$first_tag"
else
    echo "$lx_output"
fi

# ── 2. All Applications submenu ───────────────────────────────────────────────
echo "All Applications,^tag(jgmenu-all-apps)"
echo "Back,^back(),go-previous"
echo "---"

# Parse all .desktop files, skip hidden/non-apps, sort by name.
# One awk pass over every file: the old per-file grep/cut/sed pipeline forked ~6000 processes and took
# over a minute of CPU on every session start. For each file the first Type=, NoDisplay=, Name=,
# Exec= and Icon= line wins (same as `grep -m1`); %f/%u style field codes are dropped from Exec.
shopt -s nullglob
files=(/usr/share/applications/*.desktop ~/.local/share/applications/*.desktop)
(( ${#files[@]} )) && awk '
  function val(l) { return substr(l, index(l, "=") + 1) }
  function flush() {
    if (cur != "" && ty == "Application" && nd != "true" && name != "") {
      gsub(/ *%[a-zA-Z]/, "", ex); sub(/[ \t\r\f\v]+$/, "", ex)
      if (ex != "") print name "," ex "," icon
    }
  }
  FNR == 1 { flush(); cur = FILENAME; ty = nd = name = ex = icon = ""; ht = hn = hm = he = hi = 0 }
  /^Type=/      && !ht { ht = 1; ty   = val($0) }
  /^NoDisplay=/ && !hn { hn = 1; nd   = val($0) }
  /^Name=/      && !hm { hm = 1; name = val($0) }
  /^Exec=/      && !he { he = 1; ex   = val($0) }
  /^Icon=/      && !hi { hi = 1; icon = val($0) }
  END { flush() }
' "${files[@]}" 2>/dev/null | sort -f
