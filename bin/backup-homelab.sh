#!/usr/bin/env bash
# ==============================================================================
# Script: /usr/local/bin/backup-homelab.sh
# Purpose: Automated enterprise backup engine with SHA-256 integrity validation
# Author: Patrick Isles
# ==============================================================================

set -euo pipefail

BACKUP_DIR="/var/backups/homelab"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ARCHIVE_NAME="homelab-backup-${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${BACKUP_DIR}/${ARCHIVE_NAME}"
CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"
CHECKSUM_PATH="${BACKUP_DIR}/${CHECKSUM_NAME}"
RETENTION_DAYS=7

# Log wrapper for journalctl auditing
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
    logger -t backup-homelab "$*"
}

log "==> Starting Homelab Infrastructure Backup..."

# 1. Ensure target directory exists with strict permissions
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# 2. Collect critical target directories
TARGETS=(
    "/etc/nginx"
    "/var/www/html"
    "/etc/ufw"
)

# Include docker monitoring stack if present
if [[ -d "/home/patisles/monitoring" ]]; then
    TARGETS+=("/home/patisles/monitoring")
fi

log "==> Archiving targets: ${TARGETS[*]}"
tar -czf "$ARCHIVE_PATH" "${TARGETS[@]}" 2>/dev/null

# 3. Generate cryptographic SHA-256 checksum
log "==> Generating SHA-256 checksum..."
(cd "$BACKUP_DIR" && sha256sum "$ARCHIVE_NAME" > "$CHECKSUM_NAME")

# 4. Verify archive integrity immediately
log "==> Verifying archive integrity against checksum..."
(cd "$BACKUP_DIR" && sha256sum -c "$CHECKSUM_NAME")

# 5. Enforce 7-day retention policy (prune stale archives)
log "==> Enforcing ${RETENTION_DAYS}-day retention policy..."
DELETED_COUNT=$(find "$BACKUP_DIR" -type f \( -name "*.tar.gz" -o -name "*.sha256" \) -mtime "+${RETENTION_DAYS}" -print -delete | wc -l)
log "    Pruned ${DELETED_COUNT} stale backup file(s)."

BACKUP_SIZE=$(du -h "$ARCHIVE_PATH" | awk '{print $1}')
log "==> Backup completed successfully: ${ARCHIVE_NAME} (${BACKUP_SIZE})"
