# Readiness checker: Python (FastAPI)

File: `app/health.py`. Wired in `main.py` with one `Check` per
dependency; the router is included before the auth dependency.

```python
from dataclasses import dataclass, field
from typing import Awaitable, Callable, Literal
import asyncio, time

Status = Literal["ok", "degraded", "fail"]

@dataclass(frozen=True)
class Check:
    name: str
    probe: Callable[[], Awaitable[None]]
    required: bool = True
    timeout_s: float = 2.0

@dataclass
class Health:
    version: str
    checks: list[Check] = field(default_factory=list)
    total_s: float = 5.0

    async def _run(self, c: Check) -> tuple[str, dict]:
        start = time.perf_counter()
        try:
            await asyncio.wait_for(c.probe(), timeout=c.timeout_s)
            return c.name, {"status": "ok", "duration_ms": _ms(start)}
        except asyncio.TimeoutError:
            return c.name, {"status": "fail", "duration_ms": _ms(start), "error": f"timeout after {c.timeout_s}s"}
        except Exception as exc:
            # A probe may raise any driver error; the report names it.
            return c.name, {"status": "fail", "duration_ms": _ms(start), "error": _short(exc)}

    async def readyz(self) -> tuple[int, dict]:
        results = dict(await asyncio.gather(*(self._run(c) for c in self.checks)))
        status: Status = "ok"
        for c in self.checks:
            if results[c.name]["status"] == "fail":
                status = "fail" if c.required else ("degraded" if status == "ok" else status)
        return (503 if status == "fail" else 200), {"status": status, "version": self.version, "checks": results}


def router(health: Health) -> APIRouter:
    r = APIRouter(tags=["health"])

    @r.get("/healthz")
    async def healthz() -> dict:
        return {"status": "ok", "version": health.version}

    @r.get("/readyz")
    async def readyz(response: Response) -> dict:
        code, body = await health.readyz()
        response.status_code = code
        return body

    return r
```

`_short(exc)` returns the first 120 characters with any host, user or
password removed. `_ms` returns integer milliseconds.

## Probes

```python
async def pg_probe() -> None:
    async with engine.connect() as conn:
        await conn.execute(text("SELECT 1"))

async def redis_probe() -> None:
    await redis.ping()

async def downstream_probe(url: str) -> None:
    r = await http.get(f"{url}/healthz", timeout=2.0)
    r.raise_for_status()

health = Health(version=settings.version, checks=[
    Check("postgres", pg_probe, required=True),
    Check("redis", redis_probe, required=False, timeout_s=1.0),
    Check("payments-api", lambda: downstream_probe(settings.payments_url), required=True),
])
```

## Kubernetes probe values

```yaml
livenessProbe:  { httpGet: { path: /healthz, port: http }, periodSeconds: 10, failureThreshold: 3 }
readinessProbe: { httpGet: { path: /readyz,  port: http }, periodSeconds: 10, timeoutSeconds: 6, failureThreshold: 3 }
startupProbe:   { httpGet: { path: /healthz, port: http }, periodSeconds: 5,  failureThreshold: 30 }
```

## Test

`httpx.AsyncClient` against the app with fake probes: all ok gives 200
and `ok`; an optional failure gives 200 and `degraded`; a required
failure gives 503 naming the check; a probe that sleeps past
`timeout_s` reports `fail` with `timeout` and the request returns under
`total_s`.
