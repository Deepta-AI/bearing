"""Object storage for the nightly reports (S3-compatible API)."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Bucket:
    endpoint: str
    name: str
    access_key_id: str
    secret_access_key: str


def reports_bucket():
    return Bucket(
        endpoint=os.getenv("S3_ENDPOINT", "https://objects.example.com"),
        name=os.getenv("S3_BUCKET", "clinic-reports"),
        access_key_id=os.environ["S3_ACCESS_KEY_ID"],
        secret_access_key=os.environ["S3_SECRET_ACCESS_KEY"],
    )
