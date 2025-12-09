#!/bin/bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Installing Node Pulse Server (Venv + Rrsync)..."

# 1. Install System Dependencies
if command -v apt-get &> /dev/null; then
    apt-get update
    apt-get install -y python3 python3-venv rsync openssh-server
elif command -v yum &> /dev/null; then
    yum install -y python3 rsync openssh-server
elif command -v dnf &> /dev/null; then
    dnf install -y python3 rsync openssh-server
else
    echo "Warning: Could not detect package manager. Ensure python3, rsync, and sshd are installed."
fi

# 2. Configure rrsync (Restricted Rsync)
RRSYNC_PATH="/usr/local/bin/rrsync"
if [ ! -f "$RRSYNC_PATH" ]; then
    echo "Setting up rrsync..."
    POSSIBLE_LOCATIONS=(
        "/usr/share/doc/rsync/scripts/rrsync"
        "/usr/share/doc/rsync/scripts/rrsync.gz"
        "/usr/share/rsync/scripts/rrsync"
    )
    
    FOUND=0
    for loc in "${POSSIBLE_LOCATIONS[@]}"; do
        if [ -f "$loc" ]; then
            if [[ "$loc" == *.gz ]]; then
                gunzip -c "$loc" > "$RRSYNC_PATH"
            else
                cp "$loc" "$RRSYNC_PATH"
            fi
            chmod +x "$RRSYNC_PATH"
            echo "Installed rrsync to $RRSYNC_PATH"
            FOUND=1
            break
        fi
    done
    
    if [ $FOUND -eq 0 ]; then
        echo "Warning: rrsync script not found in common locations."
        echo "Attempting to download latest rrsync from Samba.org..."
        if curl -sSL "https://git.samba.org/?p=rsync.git;a=blob_plain;f=support/rrsync;hb=HEAD" -o "$RRSYNC_PATH"; then
             chmod +x "$RRSYNC_PATH"
             echo "Downloaded rrsync to $RRSYNC_PATH"
        else
             echo "Error: Failed to install rrsync. Please install manually."
             exit 1
        fi
    fi
else
    echo "rrsync already exists at $RRSYNC_PATH"
fi


# 3. Create user
if ! id "nodepulse" &>/dev/null; then
    useradd -r -s /bin/bash -d /var/nodepulse nodepulse
    echo "User 'nodepulse' created."
else
    echo "User 'nodepulse' already exists."
fi


# 4. Directory structure (Create keys before restarting SSHD)
mkdir -p /var/nodepulse/{status,server,venv}
mkdir -p /var/nodepulse/.ssh
touch /var/nodepulse/.ssh/authorized_keys
chmod 700 /var/nodepulse/.ssh
chmod 600 /var/nodepulse/.ssh/authorized_keys
chown -R nodepulse:nodepulse /var/nodepulse

# 5. Configure SSHD (Explicit Security)
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    if ! grep -q "Match User nodepulse" "$SSHD_CONFIG"; then
        echo "Configuring sshd for nodepulse user..."
        # Append Match User block to sshd_config
        # We use explicit AuthorizedKeysFile just in case, though %h default would work
        cat >> "$SSHD_CONFIG" <<EOF

# Node Pulse Restricted User
Match User nodepulse
    AuthorizedKeysFile /var/nodepulse/.ssh/authorized_keys
    PasswordAuthentication no
    PermitEmptyPasswords no
    X11Forwarding no
    AllowTcpForwarding no
    AllowAgentForwarding no
EOF
        
        # Reload/Restart SSHD
        if command -v systemctl &> /dev/null; then
            systemctl restart sshd 2>/dev/null || systemctl restart ssh || echo "Warning: Could not restart sshd. Please restart manually."
        elif command -v service &> /dev/null; then
            service sshd restart 2>/dev/null || service ssh restart || echo "Warning: Could not restart sshd. Please restart manually."
        else
             echo "Warning: Could not restart sshd. Please restart existing ssh daemon manually."
        fi
        echo "sshd_config updated."
    else
        echo "sshd_config already configured for nodepulse."
    fi
else
    echo "Warning: $SSHD_CONFIG not found. Skipping explicit SSHD config."
fi

# 6. Deploy App and venv
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

if [ -f "$SCRIPT_DIR/app.py" ]; then
    cp "$SCRIPT_DIR/app.py" /var/nodepulse/server/
    cp "$SCRIPT_DIR/config.py" /var/nodepulse/server/
    cp "$SCRIPT_DIR/start_server.sh" /var/nodepulse/server/
    chmod +x /var/nodepulse/server/*.sh
    
    mkdir -p /var/nodepulse/server/templates
    cp "$SCRIPT_DIR/templates/dashboard.html" /var/nodepulse/server/templates/
else 
    echo "Error: Source files not found in $SCRIPT_DIR"
    exit 1
fi

# Create venv if not exists
if [ ! -f "/var/nodepulse/venv/bin/python" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv /var/nodepulse/venv
    # Fix ownership immediately
    chown -R nodepulse:nodepulse /var/nodepulse/venv
fi

# 7. Systemd Service
cp "$SCRIPT_DIR/nodepulse-server.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable nodepulse-server
systemctl restart nodepulse-server

echo "Server installation complete."
echo "Ensure 'rrsync' is working."
echo "Add client keys to /var/nodepulse/.ssh/authorized_keys like this:"
echo 'command="/usr/local/bin/rrsync /var/nodepulse/status/",restrict ssh-ed25519 ...'
