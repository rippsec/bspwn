#!/usr/bin/env python3
"""
Generate jgmenu CSV from /etc/xdg/menus/applications-merged/kali-applications.menu
Usage: kali-menu.py [path-to-kali-applications.menu]
"""
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

MENU_FILE = os.environ.get(
    "JGMENU_KALI_MENU",
    "/etc/xdg/menus/applications-merged/kali-applications.menu"
)
APPLICATION_DIRS = [
    Path(p)
    for p in os.environ.get("XDG_DATA_DIRS", "/usr/share:/usr/local/share").split(":")
] + [Path.home() / ".local/share"]
APPLICATION_DIRS = [d / "applications" for d in APPLICATION_DIRS if (d / "applications").exists()]


def get_category(menu_elem):
    incl = menu_elem.find("Include")
    if incl is None:
        return None
    and_elem = incl.find("And")
    if and_elem is None:
        return None
    cat = and_elem.find("Category")
    return cat.text.strip() if cat is not None and cat.text else None


def get_name(menu_elem):
    name_elem = menu_elem.find("Name")
    return name_elem.text.strip() if name_elem is not None and name_elem.text else ""


def tag_id(name):
    return re.sub(r"[^a-zA-Z0-9_-]", "_", name).strip("_") or "menu"


def csv_desc(s):
    """Escape description for jgmenu CSV; only use triple-quotes if comma present."""
    if "," in s:
        return '"""' + s.replace('"', '""') + '"""'
    return s


def find_desktop_by_category(category):
    if not category:
        return []
    results = []
    seen = set()
    for app_dir in APPLICATION_DIRS:
        if not app_dir.is_dir():
            continue
        for f in app_dir.rglob("*.desktop"):
            try:
                text = f.read_text(encoding="utf-8", errors="ignore")
            except Exception:
                continue
            if "Categories=" not in text:
                continue
            cat_match = re.search(r"^Categories=(.*)$", text, re.MULTILINE)
            if not cat_match:
                continue
            cats = [c.strip() for c in cat_match.group(1).split(";") if c.strip()]
            if category not in cats:
                continue
            name = ""
            exec_line = ""
            icon = ""
            try_exec = ""
            terminal = False
            for line in text.split("\n"):
                if line.startswith("Name="):
                    name = line[5:].strip()
                elif line.startswith("Exec="):
                    exec_line = line[5:].strip()
                elif line.startswith("Icon="):
                    icon = line[5:].strip()
                elif line.startswith("TryExec="):
                    try_exec = line[8:].strip()
                elif line.startswith("Terminal="):
                    terminal = line[9:].strip().lower() == "true"
            if not name or not exec_line:
                continue
            key = (name, exec_line)
            if key in seen:
                continue
            seen.add(key)
            exec_line = re.sub(r" %[fFuUdDnNickvm]", "", exec_line)
            if terminal and exec_line:
                exec_line = f"x-terminal-emulator -e {exec_line}"
            results.append((name, exec_line, icon or "applications-other"))
    return sorted(results, key=lambda x: x[0].lower())


def emit_menu(menu_elem, parent_tag_prefix=""):
    name = get_name(menu_elem)
    category = get_category(menu_elem)
    children = list(menu_elem.findall("Menu"))
    tag = tag_id(parent_tag_prefix + name)

    # Submenus first (as entries)
    for ch in children:
        ch_name = get_name(ch)
        ch_tag = tag_id(tag + "_" + ch_name)
        print(f'{csv_desc(ch_name)},^checkout({ch_tag}),applications-other')

    # Tag for submenus (recurse with prefix so child tag = tag + "_" + child_name)
    for ch in children:
        ch_name = get_name(ch)
        ch_tag = tag_id(tag + "_" + ch_name)
        print(f"^tag({ch_tag})")
        emit_menu(ch, tag + "_")

    # This menu's own apps (if it has a category)
    if category:
        for app_name, exec_cmd, icon in find_desktop_by_category(category):
            print(f'{csv_desc(app_name)},{exec_cmd},{icon}')


def main():
    menu_path = sys.argv[1] if len(sys.argv) > 1 else MENU_FILE
    if not os.path.isfile(menu_path):
        sys.stderr.write(f"Menu file not found: {menu_path}\n")
        sys.exit(1)
    root = ET.parse(menu_path).getroot()
    layout = root.find("Layout")
    if layout is None:
        sys.stderr.write("No Layout in menu file\n")
        sys.exit(1)
    order = [
        m.text.strip()
        for m in layout.findall("Menuname")
        if m.text and m.text.strip() != "Usual Applications"
    ]
    merge = layout.find("Merge")
    menus_by_name = {}
    for menu in root.findall("Menu"):
        n = get_name(menu)
        if n:
            menus_by_name[n] = menu
    for name in order:
        if name in menus_by_name:
            menu = menus_by_name[name]
            tag = tag_id(name)
            print(f'{csv_desc(name)},^checkout({tag}),applications-other')
    for name in order:
        if name in menus_by_name:
            print(f"^tag({tag_id(name)})")
            emit_menu(menus_by_name[name], "")


if __name__ == "__main__":
    main()
