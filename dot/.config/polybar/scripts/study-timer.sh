#!/bin/bash

# Enhanced Study Timer Script for Polybar
# Features: Custom duration, auto-reset after long pauses, sound notifications

TIMER_FILE="/tmp/study_timer"
STATE_FILE="/tmp/study_timer_state"
CONFIG_FILE="$HOME/.config/polybar/study-timer.conf"

# Default settings
DEFAULT_DURATION=2700  # 45 minutes
AUTO_RESET_THRESHOLD=3600  # 1 hour - auto reset if paused longer than this
NOTIFICATION_SOUND=true
FINAL_COUNTDOWN=300  # Show warning in last 5 minutes

# Icons
PLAY_ICON=""
PAUSE_ICON=""
RESET_ICON=""
WARNING_ICON=""

# Colors
ACTIVE_COLOR="#a3be8c"
INACTIVE_COLOR="#d08770"
PAUSED_COLOR="#ebcb8b"
WARNING_COLOR="#bf616a"

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        # Create default config
        cat > "$CONFIG_FILE" << EOF
# Study Timer Configuration
DURATION=${DEFAULT_DURATION}
AUTO_RESET_THRESHOLD=${AUTO_RESET_THRESHOLD}
NOTIFICATION_SOUND=${NOTIFICATION_SOUND}
FINAL_COUNTDOWN=${FINAL_COUNTDOWN}
EOF
    fi
    DURATION=${DURATION:-$DEFAULT_DURATION}
}

get_current_time() {
    date +%s
}

play_sound() {
    if [[ "$NOTIFICATION_SOUND" == "true" ]]; then
        # Try different sound players
        if command -v paplay >/dev/null 2>&1; then
            paplay /usr/share/sounds/sound-icons/capital 2>/dev/null &
        elif command -v aplay >/dev/null 2>&1; then
            aplay /usr/share/sounds/sound-icon/capital 2>/dev/null &
        fi
    fi
}

init_timer() {
    if [[ ! -f "$TIMER_FILE" ]]; then
        echo "0" > "$TIMER_FILE"
        echo "stopped" > "$STATE_FILE"
    fi
}

start_timer() {
    local current_time=$(get_current_time)
    local state=$(cat "$STATE_FILE" 2>/dev/null || echo "stopped")
    
    if [[ "$state" == "stopped" ]]; then
        echo "$current_time" > "$TIMER_FILE"
        echo "0" > "${TIMER_FILE}_elapsed"
        play_sound
    elif [[ "$state" == "paused" ]]; then
        local pause_elapsed=$(cat "${TIMER_FILE}_elapsed" 2>/dev/null || echo "0")
        local pause_start=$(cat "${TIMER_FILE}_pause_start" 2>/dev/null || echo "$current_time")
        local pause_duration=$((current_time - pause_start))
        
        # Auto-reset if paused for too long
        if [[ $pause_duration -gt $AUTO_RESET_THRESHOLD ]]; then
            reset_timer
            echo "$current_time" > "$TIMER_FILE"
            echo "0" > "${TIMER_FILE}_elapsed"
            notify-send "Study Timer" "Timer reset due to long pause (${pause_duration}s)" 2>/dev/null || true
        else
            local new_start_time=$((current_time - pause_elapsed))
            echo "$new_start_time" > "$TIMER_FILE"
            rm -f "${TIMER_FILE}_pause_start"
        fi
        play_sound
    fi
    
    echo "running" > "$STATE_FILE"
}

pause_timer() {
    local current_time=$(get_current_time)
    local start_time=$(cat "$TIMER_FILE" 2>/dev/null || echo "$current_time")
    local elapsed=$((current_time - start_time))
    
    echo "$elapsed" > "${TIMER_FILE}_elapsed"
    echo "$current_time" > "${TIMER_FILE}_pause_start"
    echo "paused" > "$STATE_FILE"
    play_sound
}

reset_timer() {
    echo "0" > "$TIMER_FILE"
    echo "0" > "${TIMER_FILE}_elapsed"
    echo "stopped" > "$STATE_FILE"
    rm -f "${TIMER_FILE}_elapsed" "${TIMER_FILE}_pause_start" "${TIMER_FILE}_warned"
    play_sound
}

get_status() {
    local current_time=$(get_current_time)
    local state=$(cat "$STATE_FILE" 2>/dev/null || echo "stopped")
    local elapsed=0
    
    case "$state" in
        "running")
            local start_time=$(cat "$TIMER_FILE" 2>/dev/null || echo "$current_time")
            elapsed=$((current_time - start_time))
            ;;
        "paused")
            elapsed=$(cat "${TIMER_FILE}_elapsed" 2>/dev/null || echo "0")
            ;;
        "stopped")
            elapsed=0
            ;;
    esac
    
    local remaining=$((DURATION - elapsed))
    
    # Handle timer completion
    if [[ $remaining -le 0 ]]; then
        remaining=0
        if [[ "$state" == "running" ]]; then
            echo "finished" > "$STATE_FILE"
            notify-send -u urgent "Study Timer" "🎉 45 minutes completed! Time for a break." 2>/dev/null || true
            paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
        fi
        state="finished"
    fi
    
    # Warning for final countdown
    if [[ "$state" == "running" && $remaining -le $FINAL_COUNTDOWN && $remaining -gt 0 ]]; then
        if [[ ! -f "${TIMER_FILE}_warned" ]]; then
            notify-send "Study Timer" "⚠️ Less than 5 minutes remaining!" 2>/dev/null || true
            paplay /usr/share/sounds/sound-icons/xylofon.wav
            touch "${TIMER_FILE}_warned"
        fi
    fi
    
    # Format time display
    local minutes=$((remaining / 60))
    local seconds=$((remaining % 60))
    local time_display=$(printf "%02d:%02d" $minutes $seconds)
    
    # Choose icon and color
    local icon=""
    local color=""
    local prefix=""
    
    case "$state" in
        "running")
            icon="$PAUSE_ICON"
            if [[ $remaining -le $FINAL_COUNTDOWN && $remaining -gt 0 ]]; then
                color="$WARNING_COLOR"
                prefix="$WARNING_ICON "
            else
                color="$ACTIVE_COLOR"
            fi
            ;;
        "paused")
            icon="$PLAY_ICON"
            color="$PAUSED_COLOR"
            # Check if pause is getting long
            local pause_start=$(cat "${TIMER_FILE}_pause_start" 2>/dev/null || echo "$current_time")
            local pause_duration=$((current_time - pause_start))
            if [[ $pause_duration -gt 300 ]]; then  # 5 minutes
                prefix="x"
            fi
            ;;
        "stopped")
            icon="$PLAY_ICON"
            color="$INACTIVE_COLOR"
            time_display="45:00"
            ;;
        "finished")
            icon="$PLAY_ICON"
            color="$INACTIVE_COLOR"
            time_display="00:00"
            prefix="o"
            ;;
    esac
    
    # Output format: [TIME] [TOGGLE_BUTTON] [RESET_BUTTON]
    echo "%{F$color}$prefix$time_display%{A1:$0 toggle:}$icon%{A}%{A1:$0 reset:}$RESET_ICON%{A}%{F-}"
}

toggle_timer() {
    local state=$(cat "$STATE_FILE" 2>/dev/null || echo "stopped")
    
    case "$state" in
        "running")
            pause_timer
            ;;
        "paused"|"stopped"|"finished")
            start_timer
            ;;
    esac
}

# Load configuration
load_config

# Initialize timer files
init_timer

# Handle arguments
case "${1:-status}" in
    "start")
        start_timer
        ;;
    "pause")
        pause_timer
        ;;
    "reset")
        reset_timer
        ;;
    "toggle")
        toggle_timer
        ;;
    "config")
        echo "Current settings:"
        echo "Duration: $((DURATION/60)) minutes"
        echo "Auto-reset threshold: $((AUTO_RESET_THRESHOLD/60)) minutes"
        echo "Notifications: $NOTIFICATION_SOUND"
        echo "Config file: $CONFIG_FILE"
        ;;
    "status"|*)
        get_status
        ;;
esac
