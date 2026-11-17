#!/usr/bin/env bash
# NVIDIA dGPU usage + temp for polybar (RTX 1000 Ada on the Dell Precision 7780).
# Doesn't call nvidia-smi while the dGPU is runtime-suspended, so it never wakes it up.
PCI=/sys/bus/pci/devices/0000:01:00.0
WARN=50

LBL='%{T2}%{F#8b919c}GPU%{F-}%{T-}'
if [[ "$(cat "$PCI/power/runtime_status" 2>/dev/null)" == "suspended" ]]; then
    echo "$LBL %{F#4a5260}off%{F-}"; exit 0
fi

IFS=', ' read -r util temp < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
    --format=csv,noheader,nounits 2>/dev/null)
[[ -z "$util" ]] && { echo "$LBL %{F#4a5260}n/a%{F-}"; exit 0; }

# value colour: normal / busy (amber) / hot or maxed (red)
col="#d8d4c7"
(( util >= WARN || temp >= 75 )) && col="#e8b04b"
(( util >= 90 || temp >= 85 )) && col="#ef6a5a"
printf '%s %%{F%s}%2d%% %s°%%{F-}\n' "$LBL" "$col" "$util" "$temp"
