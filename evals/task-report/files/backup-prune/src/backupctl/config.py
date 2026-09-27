"""Defaults for backupctl. Flags override these; BACKUPCTL_* variables set them."""

import os

DEFAULT_KEEP = int(os.environ.get("BACKUPCTL_KEEP", "3"))
BACKUP_DIR = os.environ.get("BACKUPCTL_DIR", "/var/backups/db")
MIRROR_URL = os.environ.get("BACKUPCTL_MIRROR_URL", "")
BUCKET = os.environ.get("BACKUPCTL_BUCKET", "db-backups")
