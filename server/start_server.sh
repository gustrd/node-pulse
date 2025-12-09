#!/bin/bash
set -euo pipefail

# This wrapper ensures packages are updated before starting the server
# It is called by the systemd service

VENV_DIR="/var/nodepulse/venv"
SERVER_DIR="/var/nodepulse/server"

# Ensure venv exists (sanity check)
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

echo "Checking for updates to dependencies..."
# Upgrade core tools and flask
pip install --upgrade pip
pip install --upgrade flask

echo "Starting Node Pulse Server..."
exec python "$SERVER_DIR/app.py"
