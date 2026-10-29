#!/usr/bin/env bash
# ==============================================================================
# Script: verify.sh
# Purpose: Health check and execution audit for Systemd Backup Pipeline
# Author: Patrick Isles
# ==============================================================================

set -euo pipefail

echo "==> [1/4] Checking Systemd Timer state..."
if systemctl is-active --quiet backup.timer; then
    echo "    Timer: ACTIVE"
else
    echo "[-] Error: backup.timer is NOT active!" >&2
    exit 1
fi

echo "==> [2/4] Triggering on-demand backup service run..."
systemctl start backup.service

echo "==> [3/4] Validating latest journalctl operational telemetry..."
journalctl -u backup.service -n 6 --no-pager

echo "==> [4/4] Verifying cryptographic integrity of latest archive..."
LATEST_CHECKSUM=$(ls -t /var/backups/homelab/*.sha256 2>/dev/null | head -n 1)

if [[ -f "$LATEST_CHECKSUM" ]]; then
    (cd /var/backups/homelab && sha256sum -c "$(basename "$LATEST_CHECKSUM")")
    echo "==> Cryptographic audit PASSED."
else
    echo "[-] Error: No backup checksum file found in /var/backups/homelab" >&2
    exit 1
fi
