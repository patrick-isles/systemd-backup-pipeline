# Automated Enterprise Systemd Backup Pipeline & Integrity Engine

A zero-cron, production-grade **Linux Backup & Disaster Recovery Pipeline** orchestrated via native **Systemd Timers** and **Systemd Services**. 

Automates timestamped infrastructure archiving, cryptographic **SHA-256** checksum verification, rotational retention pruning, and structured `systemd-journald` operational auditing.

---

## Architectural Workflow

```
┌────────────────────────────────────────┐
│             Systemd Timer              │
│  - backup.timer (Daily at 03:00:00)    │
│  - Persistent catch-up enabled         │
└───────────────────┬────────────────────┘
                    │ Triggers
                    ▼
┌────────────────────────────────────────┐
│             Systemd Service            │
│  - backup.service (Type=oneshot)       │
│  - StandardOutput=journal              │
└───────────────────┬────────────────────┘
                    │ Executes
                    ▼
┌────────────────────────────────────────────────────────┐
│       Backup Engine (/usr/local/bin/backup-homelab.sh) │
│                                                        │
│  1. Snapshot Targets (/etc/nginx, /var/www, /etc/ufw)  │
│  2. Compress to /var/backups/homelab/ (Mode 700)       │
│  3. Compute & verify cryptographic SHA-256 checksum    │
│  4. Prune archives older than 7 days (Disk protection) │
│  5. Emit structured events to journald / syslog        │
└────────────────────────────────────────────────────────┘
```

---

## Core Engineering Capabilities

### 1. Zero-Cron Native Systemd Orchestration
Eliminates archaic cron jobs in favor of modern, auditable systemd units:
* **`Persistent=true`**: Guarantees missed backups execute immediately upon server boot if the machine was offline during the 03:00 scheduled window.
* **`RandomizedDelaySec=60`**: Prevents storage I/O thundering herds across multi-node infrastructure.
* **Atomic Logging**: All standard out and error streams route directly into the kernel/systemd journal (`journalctl -u backup.service`).

### 2. Immediate Cryptographic Checksum Validation
Every generated archive is paired with an external SHA-256 integrity hash. The engine immediately validates the archive against its checksum before reporting success:
```bash
sha256sum "$ARCHIVE_NAME" > "$CHECKSUM_NAME"
sha256sum -c "$CHECKSUM_NAME"
# Output: homelab-backup-YYYYMMDD_HHMMSS.tar.gz: OK
```
This guarantees backup corruption or bit rot is caught immediately at creation time, rather than during a disaster recovery emergency.

### 3. Automated Storage Protection (7-Day Retention)
Prevents disk space exhaustion through deterministic retention enforcement:
```bash
find "$BACKUP_DIR" -type f \( -name "*.tar.gz" -o -name "*.sha256" \) -mtime +7 -delete
```

### 4. Privilege Isolation
The backup directory (`/var/backups/homelab`) is strictly enforced at permissions `700` (`drwx------ root root`), preventing unauthorized read access to firewall rules, webroots, or configuration secrets by unprivileged system users.

---

## Repository Structure

```
.
├── bin/
│   └── backup-homelab.sh      # Core POSIX backup engine with integrity checks
├── systemd/
│   ├── backup.service         # Oneshot systemd service unit
│   └── backup.timer           # Systemd calendar timer definition (03:00 daily)
├── scripts/
│   ├── install.sh             # Automated deployment & activation installer
│   └── verify.sh              # Systemd timer health check & audit script
├── LICENSE                    # MIT License
└── README.md                  # System architecture & documentation
```

---

## Quickstart & Deployment

### 1. Deploy to Target Host
Clone this repository and run the automated installer with root privileges:
```bash
sudo ./scripts/install.sh
```

### 2. Verify Timer State
Inspect the active systemd timer queue:
```bash
systemctl list-timers backup.timer
```

Expected output:
```text
NEXT                        LEFT LAST PASSED UNIT         ACTIVATES
Thu 2026-10-29 03:00:55 PDT   9h -         - backup.timer backup.service
```

### 3. Trigger On-Demand Verification
Execute the audit script to trigger a test run and verify the cryptographic checksum:
```bash
sudo ./scripts/verify.sh
```

Expected output:
```text
==> [1/4] Checking Systemd Timer state...
    Timer: ACTIVE
==> [2/4] Triggering on-demand backup service run...
==> [3/4] Validating latest journalctl operational telemetry...
homelab-backup-20261028_171022.tar.gz: OK
Backup completed successfully: homelab-backup-20261028_171022.tar.gz (40K)
==> [4/4] Verifying cryptographic integrity of latest archive...
homelab-backup-20261028_171022.tar.gz: OK
==> Cryptographic audit PASSED.
```

---

## Disaster Recovery & Restoration

To restore infrastructure state from a verified backup archive:
```bash
# 1. Verify archive integrity prior to extraction
cd /var/backups/homelab
sha256sum -c homelab-backup-YYYYMMDD_HHMMSS.tar.gz.sha256

# 2. Extract configuration archive to root filesystem
sudo tar -xzvf homelab-backup-YYYYMMDD_HHMMSS.tar.gz -C /
```

---

## Author
**Patrick Isles**  
*Systems Administration & Infrastructure Engineering*  
- GitHub: [github.com/patrick-isles](https://github.com/patrick-isles)  
- LinkedIn: [linkedin.com/in/patrick-isles-78aba6232](https://www.linkedin.com/in/patrick-isles-78aba6232/)

---

## License
MIT License. Open for educational and enterprise infrastructure reference.
