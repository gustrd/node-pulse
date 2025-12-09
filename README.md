# Node Pulse

Node Pulse is a lightweight monitoring system where distributed machines periodically push status files to a central server, which renders a live HTML dashboard.

## Overview
- **Client**: Runs a bash script via cron to generate and push status (via Rsync/SSH).
- **Server**: Flask application that renders a dashboard based on received status files. Uses `rrsync` (restricted rsync) and a dedicated `nodepulse` user with restricted SSH permissions.

## Project Structure
```
/
├── client/
│   ├── install.sh         # Client installation script
│   ├── push.sh            # Main script run by cron
│   ├── generate_status.sh # Status generation logic
│   └── config             # Client configuration
├── server/
│   ├── install.sh         # Server installation script
│   ├── start_server.sh    # Server startup wrapper (updates venv)
│   ├── app.py             # Flask dashboard application
│   ├── config.py          # Server configuration
│   ├── nodepulse-server.service # Systemd unit
│   └── templates/
│       └── dashboard.html # Dashboard template
└── guidelines.md          # Architecture reference
```

## Installation

### Server Setup
1.  Navigate to the `server` directory.
2.  Run the install script as root:
    ```bash
    sudo ./install.sh
    ```
3.  This will:
    - Create a `nodepulse` user.
    - Configure `/etc/ssh/sshd_config` with a `Match User nodepulse` block to enforce security (disable forwarding, passwords, etc.).
    - Set up `/var/nodepulse` directory structure.
    - Install `python3-venv` and `rsync`.
    - Setup `rrsync` (restricted rsync script).
    - Create a Python virtual environment at `/var/nodepulse/venv`.
    - Enable and start the `nodepulse-server` systemd service.

### Client Setup
1.  Navigate to the `client` directory.
2.  Run the install script as root:
    ```bash
    sudo ./install.sh
    ```
3.  This will:
    - Install `rsync` if missing.
    - Install scripts to `/opt/nodepulse`.
    - Generate an SSH key (`/opt/nodepulse/nodepulse.key`).
    - Setup a cron job to run every minute.
4.  **Configuration**:
    - Edit `/opt/nodepulse/config` to set `SERVER_HOST` and `NODE_NAME`.

### Connecting Client to Server
After installing the client, you must authorize its key on the server.

1.  **On the Client**:
    Copy the public key content:
    ```bash
    cat /opt/nodepulse/nodepulse.key.pub
    ```

2.  **On the Server**:
    Add the key to `/var/nodepulse/.ssh/authorized_keys`. The install script configures `sshd` to look exactly here.
    
    Add the `command` restriction pointing to `rrsync` for maximum security:
    
    ```
    command="/usr/local/bin/rrsync /var/nodepulse/status/",restrict ssh-ed25519 AAAA... node-name
    ```
    
    This restricts the SSH connection to only allow `rsync` operations within the `/var/nodepulse/status/` directory.

## License
MIT
