#!/usr/bin/env bash
# NVIDIA dGPU usage + temp for polybar (RTX 1000 Ada on the Dell Precision 7780).
# Doesn't call nvidia-smi while the dGPU is runtime-suspended, so it never wakes it up.
PCI=/sys/bus/pci/devices/0000:01:00.0
WARN=50

LBL='%{T2}%{F#8e9099}GPU%{F-}%{T-}'
if [[ "$(cat "$PCI/power/runtime_status" 2>/dev/null)" == "suspended" ]]; then
    echo "$LBL %{F#4b4d55}off%{F-}"; exit 0
fi

IFS=', ' read -r util temp < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
    --format=csv,noheader,nounits 2>/dev/null)
[[ -z "$util" ]] && { echo "$LBL %{F#4b4d55}n/a%{F-}"; exit 0; }

# value tone: normal (grey) / busy (white) / hot or maxed (inverted)
col="#b0ada7"
(( util >= WARN || temp >= 75 )) && col="#f2efe9"
if (( util >= 90 || temp >= 85 )); then   # alarm: inverted (monochrome palette)
    printf '%s %%{B#e6e3dd}%%{F#111214} %2d%% %s° %%{F-}%%{B-}\n' "$LBL" "$util" "$temp"; exit 0
fi
printf '%s %%{F%s}%2d%% %s°%%{F-}\n' "$LBL" "$col" "$util" "$temp"
