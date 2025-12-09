#!/bin/bash
set -euo pipefail

# This script adds a client SSH public key to the server's authorized_keys
# with the correct rrsync restrictions.

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root."
  exit 1
fi

AUTH_KEYS="/var/nodepulse/.ssh/authorized_keys"
RRSYNC="/usr/local/bin/rrsync"
STATUS_DIR="/var/nodepulse/status/"

# Get key from argument or stdin
KEY=""
if [ $# -ge 1 ]; then
    KEY="$1"
elif [ -p /dev/stdin ]; then
    KEY=$(cat)
else
    echo "Usage: sudo ./add_client.sh \"<ssh-public-key>\""
    echo "   OR: cat id_ed25519.pub | sudo ./add_client.sh"
    exit 1
fi

# Trimming whitespace
KEY=$(echo "$KEY" | xargs)

if [ -z "$KEY" ]; then
    echo "Error: Empty key provided."
    exit 1
fi

# Basic validation
if [[ ! "$KEY" =~ ^ssh- ]]; then
    echo "Error: Key does not appear to be a valid SSH public key (must start with 'ssh-')."
    echo "Input was: ${KEY:0:20}..."
    exit 1
fi

if [ ! -f "$AUTH_KEYS" ]; then
    echo "Error: Authorized keys file not found at $AUTH_KEYS."
    echo "Has the server been installed correctly?"
    exit 1
fi

# Check if key is already there (matching the unique key hash part)
# SSH keys are usually "type key comment". We rely on the key part (2nd field).
KEY_HASH=$(echo "$KEY" | awk '{print $2}')

if grep -q "$KEY_HASH" "$AUTH_KEYS"; then
    echo "Warning: This key is already present in authorized_keys."
    exit 0
fi

# Construct the authorized_keys line
# We restricts the key to only run rrsync on the status directory
ENTRY="command=\"$RRSYNC $STATUS_DIR\",restrict $KEY"

echo "$ENTRY" >> "$AUTH_KEYS"

# Fix permissions just in case owner changed during append (though >> usually preserves)
chown nodepulse:nodepulse "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

echo "Success: Client key added."
