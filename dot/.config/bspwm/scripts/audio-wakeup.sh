#!/bin/bash
# Audio wakeup script to ensure PipeWire/PulseAudio is active on login
# This fixes volume controls not working until pavucontrol is opened
# 
# Main issue: Audio cards default to "pro-audio" profile which doesn't work
# with normal desktop volume controls. We need to set analog-stereo profile.

# Wait for audio system to be fully ready
sleep 2

# Fix the main issue: Set correct audio profile for built-in audio
# This ensures volume controls work properly
pactl set-card-profile alsa_card.pci-0000_00_1b.0 output:analog-stereo+input:analog-stereo 2>/dev/null

# Disable HDMI audio to avoid confusion (optional)
pactl set-card-profile alsa_card.pci-0000_00_03.0 off 2>/dev/null || true

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
