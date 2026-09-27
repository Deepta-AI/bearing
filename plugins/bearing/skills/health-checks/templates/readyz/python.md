# Readiness checker: Python (FastAPI)

File: `app/health.py`. Wired in `main.py` with one `Check` per
dependency; the router is included before the auth dependency.

```python
from dataclasses import dataclass, field
from typing import Awaitable, Callable, Literal
import asyncio, logging, time

log = logging.getLogger(__name__)

Status = Literal["ok", "degraded", "fail"]

@dataclass(frozen=True)
class Check:
    name: str
    probe: Callable[[], Awaitable[None]]
    required: bool = True
    timeout_s: float = 1.0

@dataclass
class Health:
    version: str
    checks: list[Check] = field(default_factory=list)
    total_s: float = 2.5  # above every timeout_s; the probe timeoutSeconds exceeds it

    async def _run(self, c: Check) -> tuple[str, dict]:
        start = time.perf_counter()
        try:
            await asyncio.wait_for(c.probe(), timeout=c.timeout_s)
            return c.name, {"status": "ok", "duration_ms": _ms(start)}
        except asyncio.TimeoutError:
            return c.name, {"status": "fail", "duration_ms": _ms(start), "error": "timeout"}
        except Exception:
            # The body is unauthenticated: a fixed word, never str(exc), which
            # carries hosts, users and database names. The log gets the detail.
            log.warning("readiness check %s failed", c.name, exc_info=True)
            return c.name, {"status": "fail", "duration_ms": _ms(start), "error": "unavailable"}

    async def readyz(self) -> tuple[int, dict]:
        tasks = {asyncio.ensure_future(self._run(c)): c.name for c in self.checks}
        done, pending = await asyncio.wait(tasks, timeout=self.total_s)
        for t in pending:  # a probe stuck in a blocking call cannot hold the response
            t.cancel()
        results = dict(t.result() for t in done)
        for name in tasks.values():
            results.setdefault(name, {"status": "fail", "duration_ms": int(self.total_s * 1000), "error": "timeout"})
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

`_ms` returns integer milliseconds; `log` is the module logger. A probe
that blocks the event loop (a sync driver call) defeats every timeout:
run sync probes with `asyncio.to_thread`.

## Probes

```python
# Its own engine, one connection, no overflow: a probe on the request
# engine waits for a pooled connection and fails every pod at peak.
probe_engine = create_async_engine(settings.database_url, pool_size=1, max_overflow=0)

async def pg_probe() -> None:
    async with probe_engine.connect() as conn:
        await conn.execute(text("SELECT 1"))

async def redis_probe() -> None:
    await redis.ping()

async def downstream_probe(url: str) -> None:
    r = await http.get(f"{url}/healthz", timeout=2.0)
    r.raise_for_status()

# required= comes from what the call sites do when the dependency fails.
health = Health(version=settings.version, checks=[
    Check("postgres", pg_probe, required=True),
    Check("redis", redis_probe, required=False, timeout_s=0.5),  # reads fall back
    Check("payments-api", lambda: downstream_probe(settings.payments_url), required=True),
])
```

## Kubernetes probe values

```yaml
livenessProbe:  { httpGet: { path: /healthz, port: http }, periodSeconds: 10, timeoutSeconds: 2, failureThreshold: 3 }
readinessProbe: { httpGet: { path: /readyz,  port: http }, periodSeconds: 10, timeoutSeconds: 4, failureThreshold: 3 }  # total 2.5 s
startupProbe:   { httpGet: { path: /healthz, port: http }, periodSeconds: 5,  failureThreshold: 30 }
```

## Test

`httpx.AsyncClient` against the app with fake probes: all ok gives 200
and `ok`; an optional failure gives 200 and `degraded`; a required
failure gives 503 naming the check; a probe that sleeps past
`timeout_s` reports `timeout` and the request returns under `total_s`;
an exception whose text holds a DSN leaves no host or user in the body;
`/healthz` answers 200 with every check failing; both paths answer
without credentials.
