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

# Parse all .desktop files, skip hidden/non-apps, sort by name
{
    for dir in /usr/share/applications ~/.local/share/applications; do
        [[ -d "$dir" ]] || continue
        for f in "$dir"/*.desktop; do
            [[ -f "$f" ]] || continue
            type=$(grep -m1 '^Type=' "$f" | cut -d= -f2-)
            [[ "$type" == "Application" ]] || continue
            nodisplay=$(grep -m1 '^NoDisplay=' "$f" | cut -d= -f2-)
            [[ "$nodisplay" == "true" ]] && continue
            name=$(grep -m1 '^Name=' "$f" | cut -d= -f2-)
            exec_cmd=$(grep -m1 '^Exec=' "$f" | cut -d= -f2- | sed 's/ *%[a-zA-Z]//g; s/[[:space:]]*$//')
            icon=$(grep -m1 '^Icon=' "$f" | cut -d= -f2-)
            [[ -z "$name" || -z "$exec_cmd" ]] && continue
            echo "$name,$exec_cmd,$icon"
        done
    done
} | sort -f
