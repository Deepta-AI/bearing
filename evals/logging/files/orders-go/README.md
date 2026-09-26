# orders

Order intake API (`cmd/api`) and a fulfilment worker (`cmd/worker`)
that drains the pending queue and emails the customer.

## Endpoints

| Route | Purpose |
| --- | --- |
| `POST /orders` | place an order (`email`, `phone`, `sku`, `qty`) |
| `GET /orders/{id}` | one order |
| `GET /orders?email=` | support desk lookup of a customer's orders |
| `GET /orders/export` | NDJSON stream of every order, for finance |
| `GET /healthz` | load balancer check, every 2 s, no key needed |

Every route except `/healthz` needs the `X-Api-Key` header.

## Configuration

Read from the environment at start; `.env.example` lists them.

| Variable | Default | Meaning |
| --- | --- | --- |
| `PORT` | 8080 | listen port |
| `API_KEY` | none | shared key for `X-Api-Key` |

`make check` runs vet and the tests.
