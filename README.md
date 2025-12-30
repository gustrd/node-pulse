# Node Pulse

Node Pulse is a lightweight, secure monitoring system where distributed machines periodically push status files to a central server via SSH/Rsync, which renders a live HTML dashboard with color-coded status indicators.

## Overview
- **Client**: Runs a bash script via cron every minute to generate and push status updates (via Rsync/SSH).
- **Server**: Flask application that renders a real-time dashboard based on received status files. Uses `rrsync` (restricted rsync) and a dedicated `nodepulse` user with layered SSH security restrictions.
- **Security**: Multi-layer security model with SSHD config restrictions and per-key command limitations.
- **Dashboard**: Auto-refreshing web interface with visual status indicators (green/grey/black) based on update freshness.

## Features

✅ **Automated Installation** - Single-script setup for both client and server  
✅ **Interactive Configuration** - Client installer prompts for server details  
✅ **Simplified Key Management** - `add_client.sh` script automates client authorization  
✅ **Visual Status Indicators** - Color-coded left border with configurable thresholds:
  - **Green**: Online - Updated within 5 minutes
  - **Grey**: Late - 5-15 minutes since last update
  - **Black**: Very Late - Over 15 minutes since last update  
✅ **Relative Time Display** - Human-readable timestamps ("2 minutes ago")  
✅ **Auto-Refresh Dashboard** - Refreshes every 30 seconds  
✅ **Timezone-Aware** - Server displays times in its local timezone  
✅ **Layered Security** - SSHD config + SSH key command restrictions

## Project Structure
```
/
├── client/
│   ├── install.sh              # Client installation script (Linux)
│   ├── install-termux.sh       # Client installation script (Android/Termux)
│   ├── push.sh                 # Main script run by cron
│   ├── generate_status.sh      # Status generation logic (Linux)
│   ├── generate_status_termux.sh # Status generation logic (Termux)
│   └── config                  # Client configuration
└── server/
    ├── install.sh         # Server installation script
    ├── add_client.sh      # Script to add client public keys
    ├── start_server.sh    # Server startup wrapper (updates venv)
    ├── app.py             # Flask dashboard application
    ├── config.py          # Server configuration (thresholds)
    ├── nodepulse-server.service # Systemd unit
    └── templates/
        └── dashboard.html # Dashboard template
```

## Installation

### Server Setup
1.  Navigate to the `server` directory.
2.  Run the install script as root:
    ```bash
    sudo ./install.sh
    ```
3.  This will:
    - Create a `nodepulse` user with locked password.
    - Configure `/etc/ssh/sshd_config` with a `Match User nodepulse` block to enforce security:
      - Key-based authentication only (no passwords)
      - Disabled port forwarding and X11 forwarding
      - Explicit `AuthorizedKeysFile` path
    - Set up `/var/nodepulse` directory structure (`status/`, `server/`, `venv/`, `.ssh/`).
    - Install system dependencies (`python3-venv`, `rsync`).
    - Setup `rrsync` (restricted rsync script) at `/usr/local/bin/rrsync`.
    - Create a Python virtual environment and install Flask.
    - Deploy the Flask application and systemd service.
    - Enable and start the `nodepulse-server` systemd service.
4.  The dashboard will be accessible at `http://<server-ip>:8080`

### Client Setup
1.  Navigate to the `client` directory.
2.  Run the install script as root:
    ```bash
    sudo ./install.sh
    ```
3.  The script will:
    - Install required dependencies (`rsync`, `cron`).
    - Install scripts to `/opt/nodepulse`.
    - Generate an SSH key pair (`/opt/nodepulse/nodepulse.key`).
    - **Prompt for server IP/hostname** and configure it automatically.
    - Auto-detect and configure the node name based on hostname.
    - Setup a cron job (`/etc/cron.d/nodepulse`) to run every minute.
    - Display the public key for server authorization.

4.  **Manual Configuration** (if needed):
    - Edit `/opt/nodepulse/config` to change `SERVER_HOST` or `NODE_NAME`.

### Client Setup (Termux/Android)

For Android devices using Termux:

1.  Navigate to the `client` directory.
2.  Run the install script (no root required):
    ```bash
    ./install-termux.sh
    ```
3.  The script will:
    - Install required packages via `pkg` (`rsync`, `cronie`, `openssh`).
    - Install scripts to `~/.nodepulse`.
    - Generate an SSH key pair (`~/.nodepulse/nodepulse.key`).
    - **Prompt for server IP/hostname** and configure it automatically.
    - Auto-detect device name from Android properties.
    - Setup a user crontab to run every minute.
    - Start `crond` daemon.
    - Display the public key for server authorization.

4.  **Keep Termux running** with a wakelock to ensure cron jobs execute:
    ```bash
    termux-wake-lock
    ```

5.  **Manual Configuration** (if needed):
    - Edit `~/.nodepulse/config` to change `SERVER_HOST` or `NODE_NAME`.

6.  **If Termux restarts**, start crond again:
    ```bash
    crond
    ```

### Connecting Client to Server

After installing the client, authorize its key on the server using the provided script:

#### Automated Method (Recommended)

1.  **On the Client**: Copy the public key:
    ```bash
    # Linux
    cat /opt/nodepulse/nodepulse.key.pub

    # Termux
    cat ~/.nodepulse/nodepulse.key.pub
    ```

2.  **On the Server**: Use the `add_client.sh` script:
    ```bash
    # Either pipe the key:
    cat client_key.pub | sudo ./add_client.sh
    
    # Or pass it as an argument:
    sudo ./add_client.sh "ssh-ed25519 AAAA... node-name"
    ```
    
    The script will:
    - Validate the SSH key format
    - Check for duplicate keys using fingerprints
    - Add the key with proper `rrsync` restrictions
    - Set correct permissions on `authorized_keys`

#### Manual Method

Add the key to `/var/nodepulse/.ssh/authorized_keys` with the command restriction:

```
command="/usr/local/bin/rrsync /var/nodepulse/status/",restrict ssh-ed25519 AAAA... node-name
```

This restricts the SSH connection to only allow `rsync` operations within `/var/nodepulse/status/`.

## Configuration

### Server Configuration

Edit `/var/nodepulse/server/config.py` to adjust status thresholds:

```python
STATUS_DIR = "/var/nodepulse/status"
STALE_WARNING_SECONDS = 300   # 5 minutes - Grey indicator (late)
STALE_CRITICAL_SECONDS = 900  # 15 minutes - Black indicator (very late)
```

After changing configuration, restart the service:
```bash
sudo systemctl restart nodepulse-server
```

### Client Configuration

Edit `/opt/nodepulse/config` (Linux) or `~/.nodepulse/config` (Termux):

```bash
SERVER_HOST=nodepulse@192.168.1.100  # Server address
NODE_NAME=web-server-01              # Display name
```

### Custom Status Script

Customize the status information by editing `/opt/nodepulse/generate_status.sh` (Linux) or `~/.nodepulse/generate_status.sh` (Termux):

```bash
#!/bin/bash
# Add custom system information here
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Disk: $(df -h / | tail -1 | awk '{print $5}')"
# Add more metrics as needed
```

## Dashboard

Access the dashboard at `http://<server-ip>:8080`

**Dashboard Features:**
- **Auto-refresh**: Updates every 30 seconds
- **Status Indicators**: Color-coded left border (green=online, grey=late, black=very late)
- **Relative Time**: "2 minutes ago" format for easy scanning
- **Node Details**: Always visible status content for each node
- **Sorted Display**: Alphabetically ordered by node name

## Troubleshooting

### Client Not Appearing on Dashboard

1. **Check cron logs**:
   ```bash
   # Linux
   tail -f /var/log/nodepulse.log

   # Termux
   tail -f ~/.nodepulse/nodepulse.log
   ```

2. **Test manual push**:
   ```bash
   # Linux
   sudo bash /opt/nodepulse/push.sh

   # Termux
   bash ~/.nodepulse/push.sh
   ```

3. **Verify SSH key authorization**:
   ```bash
   # Linux
   ssh -i /opt/nodepulse/nodepulse.key nodepulse@<server-ip>

   # Termux
   ssh -i ~/.nodepulse/nodepulse.key nodepulse@<server-ip>
   ```
   Should see: `This rrsync supports protocol versions 27 to 30`

### Server Issues

1. **Check service status**:
   ```bash
   sudo systemctl status nodepulse-server
   ```

2. **View logs**:
   ```bash
   sudo journalctl -u nodepulse-server -f
   ```

3. **Check file permissions**:
   ```bash
   ls -la /var/nodepulse/status/
   ```

### Cron Job Not Running

1. **Verify cron service**:
   ```bash
   sudo systemctl status cron  # or crond on RHEL/CentOS
   ```

2. **Check cron file**:
   ```bash
   cat /etc/cron.d/nodepulse
   ```

### Termux Client Issues

1. **Check if crond is running**:
   ```bash
   pgrep crond
   ```
   If not running, start it: `crond`

2. **Check logs**:
   ```bash
   tail -f ~/.nodepulse/nodepulse.log
   ```

3. **Test manual push**:
   ```bash
   bash ~/.nodepulse/push.sh
   ```

4. **Verify crontab**:
   ```bash
   crontab -l
   ```

5. **Ensure wakelock is active**:
   ```bash
   termux-wake-lock
   ```

## Security Model

Node Pulse implements defense-in-depth security:

1. **SSHD Level** (`/etc/ssh/sshd_config`):
   - Dedicated user match block
   - Key-based authentication only
   - Disabled forwarding and tunneling
   - Explicit authorized keys path

2. **SSH Key Level** (`authorized_keys`):
   - `command=""` restriction enforces only rsync
   - `restrict` option disables all other capabilities
   - Per-key directory isolation via `rrsync`

3. **Application Level**:
   - Flask app runs as `nodepulse` user
   - Read-only access to status files
   - No user input processing
   - Minimal attack surface

## License
MIT
