"""The off-site backup mirror: a small internal HTTP service holding a copy of each dump."""

import httpx


class RemoteStore:
    def __init__(self, base_url, bucket, client=None):
        self.bucket = bucket
        self.client = client or httpx.Client(base_url=base_url, timeout=30)

    def list(self):
        r = self.client.get(f"/buckets/{self.bucket}/objects")
        r.raise_for_status()
        return [o["name"] for o in r.json()["objects"]]

    def delete(self, name):
        r = self.client.delete(f"/buckets/{self.bucket}/objects/{name}")
        r.raise_for_status()
