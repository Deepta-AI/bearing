# linkd API

## POST /links

Body: `{"url": "<absolute http or https URL>", "ttl_seconds": <optional, 0 = never>}`.

- 201 `{"code": "<7 chars>", "expires_at": "<RFC 3339, only when the link expires>"}`
- 400 when the body is not JSON, or `url` is not an absolute http or https URL.
  Partner integrations call this endpoint directly, not through the web form.
- `ttl_seconds` is any non-negative whole number of seconds; anything above
  30 days is capped at 30 days, not rejected.

## GET /{code}

- 302 to the stored URL.
- 404 when the code is unknown.
- 410 once the link has expired (from `expires_at` inclusive).
- A trailing slash is accepted: `/{code}/` behaves like `/{code}`. The
  spring campaign's printed QR codes carry one and cannot be reprinted.
