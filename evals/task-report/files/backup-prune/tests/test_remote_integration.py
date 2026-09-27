"""Runs against a real backup mirror; CI provides one (make test-integration)."""

import os

import pytest

from backupctl.prune import prune_remote
from backupctl.remote import RemoteStore

pytestmark = pytest.mark.integration


@pytest.fixture
def store():
    url = os.environ.get("BACKUPCTL_MIRROR_URL")
    if not url:
        pytest.fail("BACKUPCTL_MIRROR_URL is not set")
    s = RemoteStore(url, os.environ["BACKUPCTL_BUCKET"])
    for d in range(1, 6):
        s.client.put(f"/buckets/{s.bucket}/objects/db-0{d}-09-2026.tar.gz", content=b"x")
    return s


def test_prune_remote_keeps_the_newest(store):
    deleted = prune_remote(store, 2)
    assert len(deleted) == 3
    assert sorted(store.list()) == ["db-04-09-2026.tar.gz", "db-05-09-2026.tar.gz"]
