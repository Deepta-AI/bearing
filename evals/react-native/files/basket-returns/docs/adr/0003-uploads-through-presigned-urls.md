# 3. Uploads go through presigned URLs from the API

Status: Accepted (2026-08-11)

## Context

Customer photos (returns, delivery problems) go to object storage. Storage
credentials in the app would let anyone who unpacks the bundle write to
the bucket.

## Decision

The app asks `POST /v1/uploads` for a short-lived presigned URL and PUTs
the file there. The app never holds a storage key or a signing secret, and
never builds a storage URL itself.

## Consequences

One extra round trip per photo. The API enforces size and type before a
URL is issued.
