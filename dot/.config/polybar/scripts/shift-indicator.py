#!/usr/bin/env python3
# ~/.config/polybar/scripts/shift-indicator.py

import time
import subprocess
from pynput import keyboard

shift_pressed = False

def on_press(key):
    global shift_pressed
    if key in [keyboard.Key.shift_l, keyboard.Key.shift_r]:
        shift_pressed = True
        print_status()

def on_release(key):
    global shift_pressed
    if key in [keyboard.Key.shift_l, keyboard.Key.shift_r]:
        shift_pressed = False
        print_status()

def print_status():
    if shift_pressed:
        # Active: highlighted background
        print(f"%{{B#ff0000}}%{{F#121212}} 󰜷 %{{F-}}%{{B-}}", flush=True)
    else:
        # Inactive: subtle appearance
        print(f"%{{F#666666}} 󰜷 %{{F-}}", flush=True)


# Initial state
print_status()

# Start listener
with keyboard.Listener(on_press=on_press, on_release=on_release) as listener:
    listener.join()
