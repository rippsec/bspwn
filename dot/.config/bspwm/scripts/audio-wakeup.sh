#!/bin/bash
# Audio wakeup script to ensure PipeWire/PulseAudio is active on login
# This fixes volume controls not working until pavucontrol is opened
# 
# Main issue: Audio cards default to "pro-audio" profile which doesn't work
# with normal desktop volume controls. We need to set analog-stereo profile.

# Wait for audio system to be fully ready
sleep 2

# Dell Precision 7780: built-in audio is the Intel PCH (00:1f.3, SOF/HDA); the
# NVIDIA HDMI/DP audio (01:00.1) is turned off to avoid confusion.
# If the PCH card got stuck on the "pro-audio" profile (volume keys don't work), reset it
# to the first non-pro profile it offers.
PCH_CARD=alsa_card.pci-0000_00_1f.3
if pactl list cards short 2>/dev/null | grep -q "$PCH_CARD" \
   && pactl list cards 2>/dev/null | awk -v c="$PCH_CARD" '$0 ~ "Name: "c {f=1} f && /Active Profile/ {print $3; exit}' | grep -q '^pro-audio$'; then
    pactl set-card-profile "$PCH_CARD" output:analog-stereo+input:analog-stereo 2>/dev/null \
      || pactl set-card-profile "$PCH_CARD" HiFi 2>/dev/null || true
fi
pactl set-card-profile alsa_card.pci-0000_01_00.1 off 2>/dev/null || true

# Wake up the default sink by querying it
pactl list sinks > /dev/null 2>&1

# Set volume to current level on default sink (wakes it up)
pactl set-sink-volume @DEFAULT_SINK@ +0% 2>/dev/null

# Ensure default sink is properly set
DEFAULT_SINK=$(pactl get-default-sink 2>/dev/null)
if [ -n "$DEFAULT_SINK" ]; then
    pactl set-default-sink "$DEFAULT_SINK" 2>/dev/null
fi

# Ensure the sink is unmuted
pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null

# Log success with actual sink info
echo "[$(date)] Audio system initialized - Profile: analog-stereo, Sink: $DEFAULT_SINK" >> /tmp/audio-wakeup.log
