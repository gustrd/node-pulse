#!/data/data/com.termux/files/usr/bin/bash
# Termux status generation script

# Timestamp - works as-is
echo "Timestamp: $(date -Iseconds)"

# Uptime - use uptime command output and parse it
UPTIME_OUT=$(uptime 2>/dev/null)
if [ -n "$UPTIME_OUT" ]; then
    # Extract the "up X days, HH:MM" or similar part
    UPTIME_PART=$(echo "$UPTIME_OUT" | sed 's/.*up //' | sed 's/,.*load.*//' | sed 's/,.*user.*//')
    echo "Uptime: ${UPTIME_PART}"
else
    echo "Uptime: N/A"
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

# Battery - requires termux-api and jq packages
if command -v termux-battery-status &>/dev/null && command -v jq &>/dev/null; then
    BATTERY_JSON=$(termux-battery-status 2>/dev/null)
    if [ -n "$BATTERY_JSON" ]; then
        PERCENTAGE=$(echo "$BATTERY_JSON" | jq '.percentage')
        STATUS=$(echo "$BATTERY_JSON" | jq -r '.status')
        echo "Battery: ${PERCENTAGE}% (${STATUS})"
    else
        echo "Battery: N/A"
    fi
else
    echo "Battery: Install termux-api and jq"
fi
