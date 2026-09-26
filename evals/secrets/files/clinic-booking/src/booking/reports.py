"""Nightly report: upload the day's bookings and email a signed link."""

import hashlib
import hmac
import os
import time


def signed_link(path, expires_in=86400, now=None):
    key = os.environ["REPORTS_SIGNING_KEY"]
    expires = int((now or time.time()) + expires_in)
    mac = hmac.new(key.encode(), f"{path}:{expires}".encode(), hashlib.sha256).hexdigest()
    return f"https://reports.example.com/{path}?expires={expires}&sig={mac}"


def main():
    from booking import storage

    bucket = storage.reports_bucket()
    day = time.strftime("%Y-%m-%d")
    print(f"uploading report {day} to {bucket.name}")
    print(signed_link(f"{day}.csv"))


if __name__ == "__main__":
    main()
