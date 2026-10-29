#!/usr/bin/env bash
# ==============================================================================
# Script: install.sh
# Purpose: Automated deployment of Systemd Backup Pipeline
# Author: Patrick Isles
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
BIN_SRC="${SCRIPT_DIR}/../bin/backup-homelab.sh"
SERVICE_SRC="${SCRIPT_DIR}/../systemd/backup.service"
TIMER_SRC="${SCRIPT_DIR}/../systemd/backup.timer"

BIN_DEST="/usr/local/bin/backup-homelab.sh"
SERVICE_DEST="/etc/systemd/system/backup.service"
TIMER_DEST="/etc/systemd/system/backup.timer"

echo "==> [1/4] Verifying root privileges..."
if [[ $EUID -ne 0 ]]; then
    echo "[-] Error: install.sh must be executed with sudo or as root." >&2
    exit 1
fi

echo "==> [2/4] Installing backup engine executable..."
install -m 755 "$BIN_SRC" "$BIN_DEST"

echo "==> [3/4] Installing Systemd service and timer units..."
install -m 644 "$SERVICE_SRC" "$SERVICE_DEST"
install -m 644 "$TIMER_SRC" "$TIMER_DEST"

echo "==> [4/4] Reloading systemd daemon and enabling timer..."
systemctl daemon-reload
systemctl enable --now backup.timer

echo "==> Deployment successful. Active timer status:"
systemctl list-timers backup.timer
