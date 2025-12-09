# Node Pulse — Architecture Document

## Overview

Node Pulse is a lightweight monitoring system where distributed machines periodically push status files to a central server via a secured SSH/Rsync tunnel.

---

## System Components

### Client (each monitored machine)

A single bash script runs via cron every minute. It generates a plain text status file and pushes it to the server using `rsync`.

### Server (central collector)

**Receiving files:** 
- User: `nodepulse`
- Security: configured via `/etc/ssh/sshd_config` using a `Match User` block.
- Restrictions: `PasswordAuthentication no`, `AllowTcpForwarding no`, `X11Forwarding no`.
- File Transfer: Enforced via `rrsync` in `authorized_keys`.

**Rendering dashboard:** 
- Python Flask app running in a `venv`.
- Auto-updates dependencies on start.

---

## Data Flow

```
┌─────────────┐         Rsync (port 22)      ┌─────────────────┐
│   Client    │  ──────────────────────────► │     Server      │
│  (cron job) │   restricted by sshd_config  │                 │
└─────────────┘   & authorized_keys          │  /var/nodepulse │
                                             │    /status/     │
┌─────────────┐                              │      ├─ node1   │
│   Client    │  ────────────────────────────│      ├─ node2   │
└─────────────┘                              │      └─ node3   │
                                             │                 │
                                             │  Python server  │
                                             │   (port 8080)   │
                                             └────────┬────────┘
                                                      │
                                                      ▼
                                              HTML Dashboard
```

---

## Security Model

1.  **SSHD Level**: `Match User nodepulse` in `sshd_config` enforces:
    - No passwords (keys only)
    - No port forwarding
    - Explicit `AuthorizedKeysFile` path

2.  **Key Level**: `authorized_keys` uses `command="rrsync ..."` to restrict the user to file system operations only within the status directory.

---

## Directory Structure

### Server

```
/var/nodepulse/
├── status/              # incoming status files
├── server/              # Python application
├── venv/                # Python Virtual Environment
└── .ssh/
    └── authorized_keys
```

### Client

```
/opt/nodepulse/
├── push.sh
├── nodepulse.key
└── status.txt
```

---

## Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Transport | SSH/Rsync + rrsync | Secure, efficient synchronization |
| Client script | Bash | Low footprint |
| Server | Python (Flask) | Rapid development |
| Security | SSHD config + rrsync | Layered defense depth |

---

## Deployment Checklist

1.  **Server**: Run `install.sh`. Verifies `python3`, `rsync`, installs `rrsync`, creates `venv`, patches `sshd_config`, starts service.
2.  **Client**: Run `install.sh`. Generates keys, sets up cron.
3.  **Link**: Add client public key to server `authorized_keys` with `command=` restriction.