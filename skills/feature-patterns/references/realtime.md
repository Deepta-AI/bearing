# Pattern: realtime

Pick the least connection that meets the latency: polling, then SSE,
then WebSocket. The server pushes events with a sequence number; the
client can always recover from a gap by refetching.

Markers: `EventSource|text/event-stream|WebSocket|gorilla/websocket|nhooyr|socket.io|Pusher|Ably|Centrifugo|long-poll`
Decision keys (ADR grep): `realtime`, `websocket`, `sse`, `push`

## Decision questions

1. Direction: server to client only, or both? Recommend SSE for one
   way (plain HTTP, auto-reconnect, proxies happy); WebSocket only when
   the client sends frequent messages (chat, cursors, games).
2. Latency need: under 1 s, or is 10 s fine? Ten seconds is polling with
   `ETag` and `If-None-Match`; no connection to manage.
3. Fan-out: how many subscribers per topic, and how many topics per
   client? Sets whether one process holds the subscriptions or a broker
   (Redis pub/sub, NATS) sits behind the servers.
4. Ordering and gaps: must the client see every event, or only the
   latest state? Every event needs a sequence and a replay endpoint;
   latest state needs a version and a refetch.
5. Auth: a token in the first request (SSE header, WebSocket query is
   visible in logs; prefer a short-lived ticket obtained over HTTPS).
6. Scale: connections per node (default 10k per Go or Node process,
   1k per Python worker with `uvicorn`), and the sticky-session need.

## Data model

```
events(id bigserial, topic, seq bigint, type, payload jsonb, created_at)   -- retained 24 h
subscriptions: in memory per node, topic -> set of connections; broker channel per topic
client state: last_seq per topic, persisted in memory (web) or storage (mobile)
```

Message shape: `{topic, seq, type, payload}`; SSE uses `id: <seq>` so
`Last-Event-ID` resumes; WebSocket sends `{type: "resume", topic, seq}`.

## Flow

1. Client connects with the ticket; server validates, subscribes to the
   topics the ticket allows.
2. Server replays events with `seq > last_seq` from `events`, then streams
   live from the broker.
3. Heartbeat every 25 s (SSE comment line, WebSocket ping); the client
   reconnects with backoff (1, 2, 4, 8 s, jitter, cap 30 s) when two
   heartbeats are missed.
4. On a gap the client cannot fill (seq older than retention), it
   refetches the resource and resets `last_seq`.

## Failure modes

| Fault | Handling |
| --- | --- |
| proxy buffers SSE | `X-Accel-Buffering: no`, `Cache-Control: no-cache`, flush after every event |
| load balancer idle timeout (60 s) | heartbeat under the timeout; document the LB setting |
| node restart | clients reconnect with `Last-Event-ID`; replay from `events` |
| broker outage | server keeps connections open, sends nothing, sets a `degraded` flag in the heartbeat; client shows a banner |
| thundering herd on reconnect | jittered backoff; server accepts at a bounded rate |
| duplicate delivery | client dedupes by `seq`; handlers are idempotent |
| message ordering across topics | ordering is per topic only; say so in the contract |
| mobile background | close the socket in background, refetch on foreground; push notifications for anything that must arrive |

## Tests to write

- a subscriber receives an event published after it connected, within 1 s
- reconnect with `Last-Event-ID` replays exactly the missed events, once
- a gap older than retention triggers the refetch path
- two nodes: an event published on node A reaches a client on node B
- a ticket for topic X cannot subscribe to topic Y
- heartbeat stops: the client reconnects within 60 s (fake timers)
- 1,000 concurrent connections on one node hold under the memory budget (k6 or a Go test)

## Per-stack pointers

- Go: SSE with `http.Flusher`; `nhooyr.io/websocket`; Redis pub/sub or NATS for fan-out.
- Python: `sse-starlette`; FastAPI WebSocket; `redis.asyncio` pub/sub; one worker per core, sticky not needed with a broker.
- React: `EventSource` (no headers: use the ticket in the URL, short-lived) or `fetch` streaming with `ReadableStream`; a hook that owns reconnect and exposes `status`.
- React Native: `react-native-sse` or WebSocket; suspend in background via `AppState`.
- Android and iOS: OkHttp `EventSource` or `WebSocket`; `URLSessionWebSocketTask`; both refetch on foreground.
