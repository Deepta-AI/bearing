# Pattern: uploads

Files go from the client straight to object storage on a presigned URL;
the API never proxies bytes. A record exists before the bytes and is
confirmed after; nothing is served until it is scanned.

Markers: `presign|PresignedURL|generate_presigned|multipart|ClamAV|clamd|sharp|Pillow|libvips|content-length-range`
Decision keys (ADR grep): `upload`, `object storage`, `virus scan`

## Decision questions

1. Direct-to-storage (presigned PUT or POST) or through the API?
   Recommend presigned: the API stays small and the upload does not hold
   a worker. Through the API only when the API must transform on the
   way in and files are under 5 MB.
2. Size limit per file and per user per day? Recommend 25 MB for
   documents, 10 MB for images, 500 MB with multipart for video; the
   number comes from the product, written into the presign policy
   (`content-length-range`), never only in the client.
3. Allowed types: by declared MIME, by sniffed magic bytes, or both?
   Recommend both; the sniff runs server-side after upload and mismatch
   quarantines the file.
4. Virus scan: inline before confirm, or async with a quarantine state?
   Recommend async with ClamAV (`clamd` container) or the cloud
   provider's malware scan; the file is `pending` until clean.
5. Image processing: on upload (worker writes derivatives) or on request
   (an image proxy with a cache)? Recommend on upload for a fixed set of
   sizes; on request when sizes are unknown or many.
6. Retention: who deletes orphans (a record with no bytes, bytes with no
   record) and after how long? Recommend a nightly job, 24 hours.

## Data model

```
files(id, owner_id, tenant_id, bucket, key, declared_mime, sniffed_mime, size_bytes,
      sha256, status[pending|clean|infected|rejected|deleted], created_at, confirmed_at, scanned_at)
file_derivatives(file_id, kind[thumb|medium|webp], key, width, height, size_bytes)
```

Key: `<tenant>/<yyyy>/<mm>/<uuid>` with the original name stored in the
row, never in the key. Bucket private; reads through presigned GET with
a short expiry or a CDN with signed cookies.

## Flow

1. `POST /files` with declared name, mime, size: creates `pending`, returns
   the presigned PUT (expiry 15 minutes, `content-length-range`, exact
   `Content-Type`).
2. Client PUTs the bytes to storage.
3. `POST /files/{id}/confirm`: HEAD the object, compare size and mime,
   sniff magic bytes, compute sha256, enqueue scan and derivatives.
4. Worker: scan; `clean` publishes derivatives, `infected` deletes the
   object and keeps the row for audit.
5. `GET /files/{id}`: 404 until `clean`; presigned GET otherwise.

## Failure modes

| Fault | Handling |
| --- | --- |
| client never PUTs | orphan sweep deletes `pending` older than 24 h |
| PUT succeeds, confirm never called | same sweep; storage lifecycle rule as a backstop |
| size or mime mismatch at confirm | `rejected`, object deleted, 422 with the reason |
| scanner down | file stays `pending`; alert on queue age; never serve unscanned |
| duplicate upload | sha256 unique per tenant; confirm returns the existing id |
| storage outage | presign fails fast with 503; no retry storm (jittered backoff in the client) |
| oversized multipart | abort incomplete multipart uploads after 24 h (lifecycle rule) |

## Tests to write

- presign refuses a size above the limit and a mime outside the list
- confirm rejects a mismatched size, a mismatched sniff, a missing object
- infected sample (EICAR) ends `infected` with the object gone and the row kept
- derivatives exist for a clean image, in every declared size
- GET before `clean` is 404; after, a presigned URL that expires
- orphan sweep removes a 25-hour-old `pending` and leaves a 23-hour one
- sha256 duplicate returns the same id

## Per-stack pointers

- Go: `aws-sdk-go-v2/service/s3` presign client; `net/http.DetectContentType`
  for the sniff; `bimg` or `imaging`; ClamAV over TCP with `clamd`.
- Python: `boto3 generate_presigned_post`; `python-magic`; `Pillow` or
  `pyvips`; `clamd` package.
- React and React Native: `fetch(url, {method: "PUT", body: file})`;
  `expo-file-system` `uploadAsync` on native; progress from `XMLHttpRequest`.
- Android and iOS: `OkHttp` PUT with a `RequestBody` from a stream;
  `URLSession.uploadTask`; never load the whole file into memory.
