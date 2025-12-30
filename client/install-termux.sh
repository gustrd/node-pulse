#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Termux-specific install script for Node Pulse Client
# Does not require root - runs in Termux's user space

echo "Installing Node Pulse Client for Termux..."

# 0. Check dependencies
ensure_dependency() {
    local cmd=$1
    local pkg=$2

    if ! command -v "$cmd" &> /dev/null; then
        echo "$cmd not found. Installing..."
        pkg install -y "$pkg"
    fi
}

ensure_dependency "rsync" "rsync"
ensure_dependency "crond" "cronie"
ensure_dependency "ssh-keygen" "openssh"

# 1. Create directory in Termux home
NODEPULSE_DIR="$HOME/.nodepulse"
mkdir -p "$NODEPULSE_DIR"

# 2. Deploy scripts
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

if [ -f "$SCRIPT_DIR/push.sh" ]; then
    cp "$SCRIPT_DIR/push.sh" "$NODEPULSE_DIR/"
    # Use Termux-specific status script if available, otherwise fall back to generic
    if [ -f "$SCRIPT_DIR/generate_status_termux.sh" ]; then
        cp "$SCRIPT_DIR/generate_status_termux.sh" "$NODEPULSE_DIR/generate_status.sh"
    else
        cp "$SCRIPT_DIR/generate_status.sh" "$NODEPULSE_DIR/"
    fi

    # Fix line endings (CRLF -> LF)
    sed -i 's/\r$//' "$NODEPULSE_DIR"/*.sh
    chmod +x "$NODEPULSE_DIR"/*.sh

    if [ ! -f "$NODEPULSE_DIR/config" ]; then
        cp "$SCRIPT_DIR/config" "$NODEPULSE_DIR/"

        # Ask for Server IP/Hostname
        read -p "Enter the server IP or Hostname (e.g., 192.168.1.100): " SERVER_IP

        # Update Config
        if [ -n "$SERVER_IP" ]; then
             sed -i "s|^SERVER_HOST=.*|SERVER_HOST=nodepulse@$SERVER_IP|" "$NODEPULSE_DIR/config"
        fi

        # Update NODE_NAME - use device hostname or a custom name
        DEVICE_NAME=$(getprop ro.product.model 2>/dev/null || hostname || echo "termux-device")
        DEVICE_NAME=$(echo "$DEVICE_NAME" | tr ' ' '-')
        sed -i "s/^NODE_NAME=.*/NODE_NAME=$DEVICE_NAME/" "$NODEPULSE_DIR/config"

        # Update paths in config to use Termux paths
        sed -i "s|/opt/nodepulse|$NODEPULSE_DIR|g" "$NODEPULSE_DIR/config"
    else
        echo "Config file already exists at $NODEPULSE_DIR/config, skipping overwrite."
    fi

    # Fix config line endings
    sed -i 's/\r$//' "$NODEPULSE_DIR/config"

    # Update push.sh to use Termux paths
    sed -i "s|/opt/nodepulse|$NODEPULSE_DIR|g" "$NODEPULSE_DIR/push.sh"
    sed -i "s|/var/log/nodepulse.log|$NODEPULSE_DIR/nodepulse.log|g" "$NODEPULSE_DIR/push.sh"
    sed -i "s|/tmp/nodepulse-status.txt|$NODEPULSE_DIR/nodepulse-status.txt|g" "$NODEPULSE_DIR/push.sh"

    # Update generate_status.sh to use Termux paths
    sed -i "s|/opt/nodepulse|$NODEPULSE_DIR|g" "$NODEPULSE_DIR/generate_status.sh"
else
    echo "Error: Source files not found in $SCRIPT_DIR"
    exit 1
fi

# 3. Generate SSH Key
KEY_PATH="$NODEPULSE_DIR/nodepulse.key"
if [ ! -f "$KEY_PATH" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "nodepulse-termux-$(hostname 2>/dev/null || echo 'device')"
    chmod 600 "$KEY_PATH"
    echo "SSH Key generated at $KEY_PATH"
else
    echo "SSH Key already exists."
fi

# 4. Setup cron job
# Start crond if not running
if ! pgrep -x crond > /dev/null; then
    echo "Starting crond..."
    crond
fi

# Setup crontab for current user
CRON_JOB="* * * * * bash $NODEPULSE_DIR/push.sh >> $NODEPULSE_DIR/nodepulse.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "nodepulse/push.sh"; then
    echo "Cron job already exists."
else
    # Add to existing crontab or create new one
    (crontab -l 2>/dev/null || true; echo "$CRON_JOB") | crontab -
    echo "Cron job configured."
fi

echo ""
echo "Client installation complete."
echo "---------------------------------------------------"
echo "Public Key to add to Server:"
cat "${KEY_PATH}.pub"
echo "---------------------------------------------------"
echo "Next steps:"
echo "1. Add the public key above to the server's ~/.ssh/authorized_keys"
echo "2. Verify $NODEPULSE_DIR/config settings if needed"
echo ""
echo "Note: Ensure crond is running (it was started by this script)."
echo "If Termux restarts, run: crond"
echo "Logs are at: $NODEPULSE_DIR/nodepulse.log"
