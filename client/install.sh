#!/bin/bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Installing Node Pulse Client..."

# 0. Check dependencies
ensure_dependency() {
    local cmd=$1
    local pkg_apt=$2
    local pkg_yum=$3
    
    if ! command -v "$cmd" &> /dev/null; then
        echo "$cmd not found. Installing..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y "$pkg_apt"
        elif command -v yum &> /dev/null; then
            yum install -y "$pkg_yum"
        else
            echo "Error: $cmd required but not found and no package manager detected."
            exit 1
        fi
    fi
}

ensure_dependency "rsync" "rsync" "rsync"

# Check for cron explicitly to ensure service is running
if ! command -v cron &> /dev/null && ! command -v crond &> /dev/null; then
    echo "cron not found. Installing..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y cron
        systemctl enable --now cron
    elif command -v yum &> /dev/null; then
        yum install -y cronie
        systemctl enable --now crond
    else
        echo "Error: cron required but not found and no package manager detected."
        exit 1
    fi
else
    # Ensure it's running if it was already installed
    if command -v systemctl &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            systemctl enable --now cron
        elif command -v yum &> /dev/null; then
            systemctl enable --now crond
        fi
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
        
        # Ask for Server IP/Hostname
        read -p "Enter the server IP or Hostname (e.g., 192.168.1.100): " SERVER_IP
        
        # Update Config
        if [ -n "$SERVER_IP" ]; then
             sed -i "s|^SERVER_HOST=.*|SERVER_HOST=nodepulse@$SERVER_IP|" /opt/nodepulse/config
        fi

        # Update NODE_NAME to match actual hostname
        sed -i "s/^NODE_NAME=.*/NODE_NAME=$(hostname)/" /opt/nodepulse/config
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
CRON_JOB="* * * * * root bash /opt/nodepulse/push.sh >> /var/log/nodepulse.log 2>&1"
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
echo "Next steps:"
echo "1. Add the public key above to the server's ~/.ssh/authorized_keys"
echo "2. Verify /opt/nodepulse/config settings if needed"
