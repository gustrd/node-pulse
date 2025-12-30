#!/data/data/com.termux/files/usr/bin/bash
# Termux status generation script

# Timestamp - works as-is
echo "Timestamp: $(date -Iseconds)"

# Uptime - /proc/uptime is accessible, parse it manually since uptime -p may not work
if [ -f /proc/uptime ]; then
    UPTIME_SECS=$(cut -d. -f1 /proc/uptime)
    DAYS=$((UPTIME_SECS / 86400))
    HOURS=$(((UPTIME_SECS % 86400) / 3600))
    MINS=$(((UPTIME_SECS % 3600) / 60))
    echo "Uptime: ${DAYS}d ${HOURS}h ${MINS}m"
else
    echo "Uptime: N/A"
fi

# Load average - /proc/loadavg may not be accessible without root
if [ -r /proc/loadavg ]; then
    echo "Load: $(cut -d' ' -f1-3 /proc/loadavg)"
else
    echo "Load: N/A"
fi

# Memory - use /proc/meminfo since free may not be available
if [ -r /proc/meminfo ]; then
    MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{printf "%.1fG", $2/1024/1024}')
    MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{printf "%.1fG", $2/1024/1024}')
    echo "Memory: ${MEM_AVAIL} avail / ${MEM_TOTAL} total"
else
    echo "Memory: N/A"
fi

# Internal storage (Termux home partition)
INTERNAL_USAGE=$(df -h "$HOME" 2>/dev/null | awk 'NR==2 {print $5 " (" $3 "/" $2 ")"}')
echo "Disk: ${INTERNAL_USAGE:-N/A}"

# SD Card - check common mount points
SDCARD=""
for path in /storage/????-???? /sdcard/Android/data; do
    if [ -d "$path" ] && df "$path" &>/dev/null; then
        SDCARD_USAGE=$(df -h "$path" 2>/dev/null | awk 'NR==2 {print $5 " (" $3 "/" $2 ")"}')
        SDCARD="$path"
        break
    fi
done
if [ -n "$SDCARD" ]; then
    echo "SD Card: ${SDCARD_USAGE}"
else
    echo "SD Card: Not found"
fi

# Battery - requires termux-api package
if command -v termux-battery-status &>/dev/null; then
    BATTERY_JSON=$(termux-battery-status 2>/dev/null)
    if [ -n "$BATTERY_JSON" ]; then
        PERCENTAGE=$(echo "$BATTERY_JSON" | grep -o '"percentage":[0-9]*' | cut -d: -f2)
        STATUS=$(echo "$BATTERY_JSON" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        echo "Battery: ${PERCENTAGE}% (${STATUS})"
    else
        echo "Battery: N/A"
    fi
else
    # Fallback: try reading from Android system files
    if [ -f /sys/class/power_supply/battery/capacity ]; then
        CAPACITY=$(cat /sys/class/power_supply/battery/capacity)
        STATUS=$(cat /sys/class/power_supply/battery/status 2>/dev/null || echo "Unknown")
        echo "Battery: ${CAPACITY}% (${STATUS})"
    else
        echo "Battery: Install termux-api for battery info"
    fi
fi
