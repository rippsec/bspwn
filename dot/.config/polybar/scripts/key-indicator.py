#!/usr/bin/env python3
import subprocess
from pynput import keyboard

caps_on = False
shift_pressed = False
ctrl_pressed = False
alt_pressed = False
super_pressed = False
tab_pressed = False

def get_caps_state():
    result = subprocess.run(["xset", "q"], capture_output=True, text=True)
    return "Caps Lock:   on" in result.stdout

def on_press(key):
    global shift_pressed, ctrl_pressed, alt_pressed, super_pressed, tab_pressed, caps_on
    caps_on = get_caps_state()

    if key in [keyboard.Key.shift_l, keyboard.Key.shift_r]:
        shift_pressed = True
    elif key in [keyboard.Key.ctrl_l, keyboard.Key.ctrl_r]:
        ctrl_pressed = True
    elif key in [keyboard.Key.alt_l, keyboard.Key.alt_r]:
        alt_pressed = True
    elif key in [keyboard.Key.cmd, keyboard.Key.cmd_l, keyboard.Key.cmd_r]:
        super_pressed = True
    elif key == keyboard.Key.tab:
        tab_pressed = True
    print_status()

def on_release(key):
    global shift_pressed, ctrl_pressed, alt_pressed, super_pressed, tab_pressed, caps_on
    caps_on = get_caps_state()

    if key in [keyboard.Key.shift_l, keyboard.Key.shift_r]:
        shift_pressed = False
    elif key in [keyboard.Key.ctrl_l, keyboard.Key.ctrl_r]:
        ctrl_pressed = False
    elif key in [keyboard.Key.alt_l, keyboard.Key.alt_r]:
        alt_pressed = False
    elif key in [keyboard.Key.cmd, keyboard.Key.cmd_l, keyboard.Key.cmd_r]:
        super_pressed = False
    elif key == keyboard.Key.tab:
        tab_pressed = False
    print_status()

def print_status():
    output = ""
    if caps_on:
        output += "%{F#FFFFFF} 󰌎 %{F-}%{B-}"
    elif tab_pressed:
        output += "%{F#FFFFFF} 󰌒 %{F-}%{B-}"
    elif shift_pressed:
        output += "%{F#FFFFFF} 󰜷 %{F-}%{B-}"
    elif ctrl_pressed:
        output += "%{F#FFFFFF} 󰘴 %{F-}%{B-}"
    elif alt_pressed:
        output += "%{F#FFFFFF} 󰘵 %{F-}%{B-}"
    elif super_pressed:
        output += "%{F#FFFFFF} 󰘳 %{F-}%{B-}"
    else:
        output += "%{F#7c8fa5} 󰌌 %{F-}"
    print(output, flush=True)

print_status()
with keyboard.Listener(on_press=on_press, on_release=on_release) as listener:
    listener.join()
