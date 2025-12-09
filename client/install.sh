#!/bin/bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Installing Node Pulse Client..."

# 0. Check dependencies
if ! command -v rsync &> /dev/null; then
    echo "rsync not found. Installing..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y rsync
    elif command -v yum &> /dev/null; then
        yum install -y rsync
    else
        echo "Error: rsync required but not found and no package manager detected."
        exit 1
    fi
fi

# 1. Create directory
mkdir -p /opt/nodepulse

# 2. Deploy scripts
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

if [ -f "$SCRIPT_DIR/push.sh" ]; then
    cp "$SCRIPT_DIR/push.sh" /opt/nodepulse/
    cp "$SCRIPT_DIR/generate_status.sh" /opt/nodepulse/
    
    # Fix line endings (CRLF -> LF)
    sed -i 's/\r$//' /opt/nodepulse/*.sh
    chmod +x /opt/nodepulse/*.sh
    
    if [ ! -f /opt/nodepulse/config ]; then
        cp "$SCRIPT_DIR/config" /opt/nodepulse/
    else
        echo "Config file already exists at /opt/nodepulse/config, skipping overwrite."
    fi
    
    # Fix config line endings
    sed -i 's/\r$//' /opt/nodepulse/config
else
    echo "Error: Source files not found in $SCRIPT_DIR"
    exit 1
fi

# 3. Generate SSH Key
KEY_PATH="/opt/nodepulse/nodepulse.key"
if [ ! -f "$KEY_PATH" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "nodepulse-$(hostname)"
    chmod 600 "$KEY_PATH"
    echo "SSH Key generated at $KEY_PATH"
else
    echo "SSH Key already exists."
fi

# 4. Cron job
CRON_JOB="* * * * * /opt/nodepulse/push.sh >> /var/log/nodepulse.log 2>&1"
CRON_FILE="/etc/cron.d/nodepulse"

if [ ! -f "$CRON_FILE" ]; then
    echo "$CRON_JOB" > "$CRON_FILE"
    chmod 644 "$CRON_FILE"
    echo "Cron job configured in $CRON_FILE"
else
    echo "Cron job already exists."
fi

echo "Client installation complete."
echo "---------------------------------------------------"
echo "Public Key to add to Server:"
cat "${KEY_PATH}.pub"
echo "---------------------------------------------------"
echo "Please edit /opt/nodepulse/config with the correct SERVER_HOST"
