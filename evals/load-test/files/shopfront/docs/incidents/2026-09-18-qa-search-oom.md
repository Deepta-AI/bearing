# qa search pod OOM-killed, 18 September 2026

Status: open. Written by the qa on-call.

## What happened

- 07:30 IST: qa-scale-up brought the pod back. Working set about 70Mi at
  07:40 (container_memory_working_set_bytes on the qa-shopfront dashboard).
- 16:15 IST: OOMKilled at the 256Mi limit, restarted, back to about 70Mi.
- The climb between the two was close to a straight line.
- Same pattern on 15, 16 and 17 September, each time in the afternoon.

## Traffic that day

The e2e suite (every 30 minutes) and manual testing through the web front
end: on average about 3 searches a second and 0.2 orders a second
(ingress logs). Most search strings are typed by hand: about 70% of the
q values in that day's log appear only once.

## Suspect

`orders.MemoryStore` keeps every order and nothing deletes the e2e
orders on qa. Proposed: restart the pod nightly.

## Notes

The dashboard shows container memory only. `/debug/vars` is reachable on
qa (the ingress blocks it in production).
