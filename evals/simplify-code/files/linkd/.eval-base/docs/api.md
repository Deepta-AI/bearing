# linkd API

## POST /links

Body: `{"url": "<absolute http or https URL>"}`.

- 201 `{"code": "<7 chars>"}`
- 400 when the body is not JSON, or `url` is not an absolute http or https URL.
  Partner integrations call this endpoint directly, not through the web form.

## GET /{code}

- 302 to the stored URL.
- 404 when the code is unknown.
