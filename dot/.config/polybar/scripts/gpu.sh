#!/usr/bin/env bash
# NVIDIA dGPU usage + temp for polybar (RTX 1000 Ada on the Dell Precision 7780).
# Doesn't call nvidia-smi while the dGPU is runtime-suspended, so it never wakes it up.
PCI=/sys/bus/pci/devices/0000:01:00.0
WARN=50

if [[ "$(cat "$PCI/power/runtime_status" 2>/dev/null)" == "suspended" ]]; then
    echo "GPU:off"; exit 0
fi

IFS=', ' read -r util temp < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
    --format=csv,noheader,nounits 2>/dev/null)
[[ -z "$util" ]] && { echo "GPU:n/a"; exit 0; }

out=$(printf "GPU:%02d%% %s°C" "$util" "$temp")
if (( util >= WARN )); then
    echo "%{B#ff0000}%{O5}${out}%{O5}%{B-}"
else
    echo "%{O5}${out}%{O5}"
fi
