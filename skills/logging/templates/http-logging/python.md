# HTTP logging middleware: Python (FastAPI, pure ASGI)

File: `app/api/middleware/loghttp.py`. Added in `main.py` after the
request id middleware so `request_id` is already bound in contextvars.

## Configuration

```python
class HttpLogSettings(BaseSettings):
    log_http: bool = Field(default=False, alias="LOG_HTTP")
    log_http_bodies: bool = Field(default=False, alias="LOG_HTTP_BODIES")
    log_http_max_bytes: int = Field(default=2048, alias="LOG_HTTP_MAX_BYTES")
    log_http_sample: float = Field(default=1.0, alias="LOG_HTTP_SAMPLE", ge=0, le=1)
```

`main.py` sets `log_http=True` when `env == "dev"` and the variable is
unset.

## Middleware

```python
REDACTED_HEADERS = {"authorization", "cookie", "set-cookie", "x-api-key"}

class LogHttpMiddleware:
    def __init__(self, app: ASGIApp, settings: HttpLogSettings) -> None:
        self.app, self.s = app, settings

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or not self.s.log_http or random.random() > self.s.log_http_sample:
            await self.app(scope, receive, send)
            return
        log = structlog.get_logger()
        start = time.perf_counter()
        req_body = bytearray()
        status, resp_body, resp_size = 500, bytearray(), 0

        async def recv() -> Message:
            m = await receive()
            if self.s.log_http_bodies and m["type"] == "http.request" and len(req_body) < self.s.log_http_max_bytes:
                req_body.extend(m.get("body", b"")[: self.s.log_http_max_bytes - len(req_body)])
            return m

        async def snd(m: Message) -> None:
            nonlocal status, resp_size
            if m["type"] == "http.response.start":
                status = m["status"]
            elif m["type"] == "http.response.body":
                chunk = m.get("body", b"")
                resp_size += len(chunk)
                if self.s.log_http_bodies and len(resp_body) < self.s.log_http_max_bytes:
                    resp_body.extend(chunk[: self.s.log_http_max_bytes - len(resp_body)])
            await send(m)

        headers = {k.decode(): ("[redacted]" if k.decode().lower() in REDACTED_HEADERS else v.decode()) for k, v in scope["headers"]}
        log.debug("http request", method=scope["method"], route=route_of(scope), headers=headers)
        try:
            await self.app(scope, recv, snd)
        finally:
            ms = int((time.perf_counter() - start) * 1000)
            log.info("http response", method=scope["method"], route=route_of(scope), status=status,
                     duration_ms=ms, outcome=outcome(status), resp_bytes=resp_size,
                     req_body=redact_body(bytes(req_body)), resp_body=redact_body(bytes(resp_body)))
```

`route_of` reads `scope["route"].path` after routing (fall back to the
raw path only in the debug line). `redact_body` parses JSON when it can
and replaces deny-list keys, else returns the truncated prefix. A pure
ASGI middleware is used because `BaseHTTPMiddleware` buffers streaming
responses and breaks background tasks.

## Flipping it at runtime

Environment only. `LOG_HTTP=true` on the deployment, restart. The
settings object is read once at import. Document all four variables in
`.env.example`.

## Test

`httpx.AsyncClient` against the app with `capture_logs()`: disabled logs
nothing; enabled logs two lines; bodies on redacts `password` and stops
at `LOG_HTTP_MAX_BYTES`.
