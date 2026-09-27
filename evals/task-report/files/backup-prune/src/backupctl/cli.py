"""Command line entry point."""

import argparse

from backupctl import config
from backupctl.prune import prune_local, prune_remote


def build_parser():
    p = argparse.ArgumentParser(prog="backupctl")
    sub = p.add_subparsers(dest="cmd", required=True)
    pr = sub.add_parser("prune", help="delete old backups, keeping the newest N")
    pr.add_argument("--dir", default=config.BACKUP_DIR, help="local backup directory")
    pr.add_argument("--keep", type=int, default=config.DEFAULT_KEEP, help="backups to keep")
    pr.add_argument("--remote", action="store_true", help="also prune the backup mirror")
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    if args.cmd == "prune":
        deleted = prune_local(args.dir, args.keep)
        for name in deleted:
            print(f"deleted {name}")
        print(f"{len(deleted)} local backups deleted")
        if args.remote:
            # Imported here so local pruning works on hosts without httpx.
            from backupctl.remote import RemoteStore

            store = RemoteStore(config.MIRROR_URL, config.BUCKET)
            gone = prune_remote(store, args.keep)
            for name in gone:
                print(f"deleted remote {name}")
            print(f"{len(gone)} remote backups deleted")
    return 0
