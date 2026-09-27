# Collector contract

`POST /collect` with a JSON body: one event object, or an array of at most
50 event objects. Each event is `{ event, props, context, sent_at }`.

| Answer | Meaning |
| --- | --- |
| 202 | stored |
| 400 | the body is not JSON or an event has no name; nothing stored |
| 413 | an array longer than 50 events, or a body over 64 KB; nothing stored |

The collector adds `received_at` and a country from the IP address (the
address itself is dropped), then writes one warehouse row per event with
the properties flattened into columns beside its own request columns
(`method`, `path`, `received_at`, `country`).
