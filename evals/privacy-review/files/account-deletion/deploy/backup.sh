#!/bin/sh
# Nightly online backup of the SQLite database to the backup volume.
set -eu
stamp=$(date +%Y%m%d)
sqlite3 /data/mealbox.db ".backup /backups/mealbox-$stamp.db"
# Keep five weeks of nightly backups.
find /backups -name 'mealbox-*.db' -mtime +35 -delete
