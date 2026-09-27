"""Choose and delete old backups, keeping the newest N."""

import os
import re

BACKUP_NAME = re.compile(r"^db-(\d{2})-(\d{2})-(\d{4})\.tar\.gz$")


def is_backup(name):
    return BACKUP_NAME.match(name) is not None


def list_backups(directory):
    return [n for n in os.listdir(directory) if is_backup(n)]


def select_for_deletion(names, keep):
    """Return the backups to delete: every backup but the `keep` newest."""
    if keep < 1:
        raise ValueError("keep must be at least 1")
    ordered = sorted(n for n in names if is_backup(n))  # oldest first
    return ordered[: max(len(ordered) - keep, 0)]


def prune_local(directory, keep):
    doomed = select_for_deletion(list_backups(directory), keep)
    for name in doomed:
        os.remove(os.path.join(directory, name))
    return doomed


def prune_remote(store, keep):
    doomed = select_for_deletion(store.list(), keep)
    for name in doomed:
        store.delete(name)
    return doomed
