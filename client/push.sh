#!/bin/bash
set -euo pipefail

# Load config
CONFIG_FILE="/opt/nodepulse/config"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

# Validation
if [ -z "${SERVER_HOST:-}" ]; then echo "Error: SERVER_HOST not set in config"; exit 1; fi
if [ -z "${NODE_NAME:-}" ]; then echo "Error: NODE_NAME not set in config"; exit 1; fi
if [ -z "${KEY_PATH:-}" ]; then echo "Error: KEY_PATH not set in config"; exit 1; fi
if [ -z "${SCRIPT_PATH:-}" ]; then echo "Error: SCRIPT_PATH not set in config"; exit 1; fi

if [ ! -x "$SCRIPT_PATH" ]; then
    echo "Error: Generation script at $SCRIPT_PATH is not executable or found."
    exit 1
fi

STATUS_FILE="/home/gustrd/nodepulse-status.txt"

# Generate status
"$SCRIPT_PATH" > "$STATUS_FILE"

# Push to server using rsync
# We use -e to specify the ssh key and options
# Since the server uses rrsync pointing to /var/nodepulse/status/, we push to the relative root "."
rsync -a -e "ssh -vvv -i $KEY_PATH -o StrictHostKeyChecking=accept-new" "$STATUS_FILE" "$SERVER_HOST:$NODE_NAME.txt"
