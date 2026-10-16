# health-checks: /healthz, /readyz and the template rules

Read when: steps 3 and 4: writing the two endpoints and their tests.

3. **`/healthz` (liveness).** Returns 200 with status and version and
touches nothing: no database, cache, network or lock that a stuck
dependency can hold. Version comes from the build (`-ldflags -X main.version`,
a package version, an env var the image sets); if the
build sets none, omit it rather than invent one. A test runs it with
every dependency check failing and still gets 200.

4. **`/readyz` (readiness).** Copy the checker from the template for the
stack. Rules the template carries, keep them when adapting:
- Checks run concurrently, each with its own timeout, and the handler
  returns at a fixed total deadline even when a probe ignores its
  context (collect results from a channel until the deadline; a
  check with no result by then is reported `fail`, `timeout`). A
  `sync.WaitGroup.Wait()` or `asyncio.gather` with no outer deadline
  hangs on such a probe.
- The body carries a fixed short reason per check (`timeout`,
  `unreachable`, `unhealthy`), never the driver error. Driver errors
  carry the host, user and database name (pgx: ``failed to connect to
  `user=orders database=orders`: 10.0.0.5:5432 (db.internal)``), and a
  regex scrubber misses some format; log the full error server side,
  sampled.
- Probes are cheap: `SELECT 1`/ping, `PING` on the cache, a
  downstream's own liveness path (`/healthz`), never its `/readyz`
  (that chains its dependencies into yours) and never a business
  endpoint.
- Probe the dependency, not your pool. `db.PingContext` on the
  request pool (`database/sql` with `SetMaxOpenConns`, pgxpool,
  SQLAlchemy, HikariCP) first waits for a free connection. At peak,
  when every pod's pool is full and the database is fine, that wait
  times out on every pod at once and readiness turns load into a
  full outage. Read the pool size and any capacity or incident note;
  give the probe its own connection (a second pool capped at 1, which
  costs replicas x 1 connections against `max_connections`, say so)
  and test that a saturated request pool leaves readiness ok.
- Both endpoints are reachable without credentials: add them to the
  auth allow list or mount them outside the auth middleware, and test
  an unauthenticated request gets 200 or 503, not 401.
- Tests: all ok 200; each optional failure 200 and degraded; each
  required failure 503 naming the check; a blocking probe that
  ignores its context returns within the total and reports timeout;
  unauthenticated access; liveness with everything down.
