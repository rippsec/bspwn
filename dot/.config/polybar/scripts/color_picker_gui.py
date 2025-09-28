#!/usr/bin/env python3
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk
import subprocess
import re
import os

def check_existing_window():
    """Check if a window with title 'Hex Color Picker' exists and close it."""
    try:
        # Search for the window by title
        window_ids = subprocess.check_output(
            ["xdotool", "search", "--name", "Hex Color Picker"]
        ).decode().strip().split()
        
        if window_ids:
            for wid in window_ids:
                subprocess.run(["xdotool", "windowclose", wid])
            return True
        return False
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False  # No window found or xdotool not installed

class ColorPicker(Gtk.Window):
    def __init__(self):
        Gtk.Window.__init__(self, title="Hex Color Picker")
        self.set_default_size(300, 200)
        
        # Main layout
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.add(vbox)

        # Title
        title = Gtk.Label(label="Hex Color Picker")
        vbox.pack_start(title, False, False, 0)

        # Color chooser widget (wheel)
        self.color_chooser = Gtk.ColorChooserWidget()
        # Connect to "color-activated" and "notify::rgba" signals
        self.color_chooser.connect("color-activated", self.on_color_picked)
        self.color_chooser.connect("notify::rgba", self.on_color_changed)
        vbox.pack_start(self.color_chooser, True, True, 0)

        # Input bar
        self.entry = Gtk.Entry(placeholder_text="#RRGGBB")
        vbox.pack_start(self.entry, False, False, 0)

        # Warning message
        self.warning = Gtk.Label(label="")
        vbox.pack_start(self.warning, False, False, 0)

        # OK/Cancel buttons
        button_box = Gtk.Box(spacing=6)
        vbox.pack_start(button_box, False, False, 0)

        self.ok_button = Gtk.Button(label="OK")
        self.ok_button.connect("clicked", self.on_ok_clicked)
        button_box.pack_start(self.ok_button, True, True, 0)

        self.cancel_button = Gtk.Button(label="Cancel")
        self.cancel_button.connect("clicked", self.on_cancel_clicked)
        button_box.pack_start(self.cancel_button, True, True, 0)

        # Connect signals
        self.entry.connect("activate", self.on_ok_clicked)  # Enter key in entry = OK
        self.connect("key-press-event", self.on_key_press)  # Global key press handler

    def on_color_picked(self, widget, color):
        hex_color = self.rgba_to_hex(color)
        self.entry.set_text(hex_color)
        self.apply_color(hex_color)

    def on_color_changed(self, widget, param):
        # This gets called continuously as the color changes (during drag)
        color = widget.get_rgba()
        hex_color = self.rgba_to_hex(color)
        self.entry.set_text(hex_color)

    def on_ok_clicked(self, widget):
        text = self.entry.get_text().strip()
        self.apply_color(text)

    def apply_color(self, hex_color):
        if re.match(r'^#[0-9A-Fa-f]{6}$', hex_color):
            autocolor_script = os.path.expanduser("~/.config/polybar/_scripts/autocolor.sh")
            subprocess.run([autocolor_script, hex_color])
            self.close()
        else:
            self.warning.set_text("Invalid format! Use #RRGGBB")

    def on_cancel_clicked(self, widget):
        self.close()

    def on_key_press(self, widget, event):
        # Handle Enter key press anywhere in the window
        if event.keyval == Gdk.KEY_Return or event.keyval == Gdk.KEY_KP_Enter:
            self.on_ok_clicked(widget)
            return True
        return False

    def rgba_to_hex(self, rgba):
        r, g, b = int(rgba.red * 255), int(rgba.green * 255), int(rgba.blue * 255)
        return f"#{r:02X}{g:02X}{b:02X}"

def main():
    win = ColorPicker()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    if check_existing_window():
        exit(0)
    main()
