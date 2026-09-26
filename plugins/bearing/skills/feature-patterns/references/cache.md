# Pattern: cache

A cache is a second copy of the truth with an expiry. Cache-aside with
a short TTL and explicit invalidation on write covers most cases; the
work is in the key design and in surviving the moment a hot key expires.

Markers: `redis|memcached|lru|cache-aside|Cache-Control|ETag|stale-while-revalidate|singleflight|@cache|functools.lru_cache`
Decision keys (ADR grep): `cache`, `redis`, `cdn`

## Decision questions

1. What is slow or frequent, with numbers? The plan names the read, its
   p95, its rate and its hit-rate target. No number, no cache.
2. Where: in process (per node, fastest, inconsistent across nodes),
   shared (Redis, consistent, a network hop), HTTP (CDN or browser, for
   public or per-user GETs)? Recommend HTTP first for GETs, shared for
   computed reads, in process only for config and reference data.
3. Staleness tolerated: seconds, minutes, or none? Sets the TTL.
   "None" means invalidate on write and a short TTL as a backstop.
4. Invalidation: by key on write (recommend), by tag or version prefix
   (for lists), or TTL only (for derived data nobody writes)?
5. Stampede protection: one node has a hot key that expires under load.
   Recommend `singleflight` (one loader per key per node) plus a jittered
   TTL; add early refresh for the top keys.
6. What must never be cached: anything authorised per user unless the
   user id is in the key; secrets; anything with a legal read-once rule.

## Key design

```
<service>:<entity>:<version>:<id>              user:v2:1234
<service>:<entity>:list:<version>:<hash of filters>   invoice:list:v1:ab12cd
```

The version is bumped in code when the shape changes; old keys expire
by TTL. Lists are invalidated by bumping a per-tenant list version key
(`invoice:list:version:<tenant>`) rather than deleting many keys.

## Data model

```
Redis: string or hash per key, TTL = base * (1 +- 10% jitter)
in process: LRU with a max entries count and a TTL; never unbounded
HTTP: Cache-Control: private, max-age=60, stale-while-revalidate=300; ETag from a content hash
```

## Flow (cache-aside)

1. Read: GET key; hit returns; miss takes the singleflight lock for the key,
   loads from the source, SETs with jittered TTL, returns.
2. Write: update the source, then DEL the key (not SET; the next read
   loads the truth). For lists, INCR the list version.
3. Negative caching: a miss in the source is cached as a tombstone with
   a short TTL (30 s) so a missing id cannot hammer the database.

## Failure modes

| Fault | Handling |
| --- | --- |
| cache down | fail open to the source with a circuit breaker; alert; never fail the request because the cache failed |
| stampede on expiry | singleflight per key per node; jittered TTL; early refresh for the top 100 keys |
| stale after write | DEL after the commit, not before; a test asserts the order |
| write then read on another node | shared cache only; in-process caches only for data that tolerates staleness |
| key collision across tenants | tenant id in the key for anything tenant-scoped |
| unbounded growth | every key has a TTL; in-process LRU has a size; `maxmemory-policy allkeys-lru` |
| cached error | never cache a 5xx; cache 404 briefly only when the id shape is valid |
| hot key on one shard | replicate the key locally (in-process layer with a 1 s TTL) |

## Tests to write

- miss then hit: the loader runs once for two sequential reads
- 50 concurrent misses on one key run the loader once (singleflight)
- write invalidates: a read after a write returns the new value
- TTL expires: a read after the TTL runs the loader again (fake clock)
- cache unavailable: the read still succeeds from the source and a metric increments
- tenant A's key never serves tenant B
- the list version bump makes every cached list for that tenant miss

## Per-stack pointers

- Go: `golang.org/x/sync/singleflight`; `github.com/redis/go-redis/v9`; `hashicorp/golang-lru/v2` with expiry.
- Python: `redis.asyncio`; `cachetools.TTLCache` guarded by an `asyncio.Lock` per key; never `lru_cache` on a method with request data.
- React: TanStack Query owns the client cache (`staleTime`, `gcTime`, `invalidateQueries` on mutation); no second store.
- Mobile: TanStack Query on RN; Room or SwiftData as the offline cache with a `fetched_at` column and the same TTL rule.
- HTTP: `ETag` plus `If-None-Match` on every GET the CDN or browser may cache; `Vary: Authorization` for private responses.
