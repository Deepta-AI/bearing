# Shop architecture

Last updated: 2026-06-02 (release 1.8.0). Drawn from `k8s/`,
`docker-compose.yml` and the Go sources.

## Containers

```mermaid
flowchart LR
  customer([Customer])
  staff([Staff])
  subgraph shop[shop]
    web[web<br/>React SPA on nginx]
    api[api<br/>Go net/http]
    worker[worker<br/>Go]
    pg[(postgres<br/>PostgreSQL 16)]
    redis[(redis<br/>cart cache)]
  end
  razorpay[[Razorpay]]
  postmark[[Postmark SMTP]]
  inventory[[inventory service]]

  customer -->|HTTPS| web
  staff -->|HTTPS| web
  web -->|/api, JSON| api
  api -->|SQL: orders, carts, outbox insert| pg
  api -->|GET/SET cart:*| redis
  worker -->|SQL: claim order.created| pg
  api -->|POST /payments/:id/capture| razorpay
  worker -->|SMTP 587| postmark
  api -.->|INVENTORY_URL, no caller found| inventory
```

## Place an order (POST /api/orders)

```mermaid
sequenceDiagram
  autonumber
  actor C as Customer
  participant H as orders.Handler.Create
  participant S as orders.Service.Place
  participant R as Razorpay
  participant DB as postgres
  C->>H: POST /api/orders {cart_id, payment_id}
  alt invalid body
    H-->>C: 400 invalid body
  end
  H->>S: Place(ctx, cartID, paymentID)
  S->>DB: SELECT total_paise FROM carts
  S->>R: capture payment
  alt capture fails
    R-->>S: error
    S-->>H: ErrPaymentFailed
    H-->>C: 502 payment not captured
  end
  S->>DB: BEGIN, INSERT orders, INSERT outbox order.created, COMMIT
  S-->>H: order
  H-->>C: 201 order
```

## Sources

| Element | Where |
| --- | --- |
| api, worker | k8s/api.yaml, k8s/worker.yaml |
| postgres | DATABASE_URL in k8s secrets, docker-compose.yml |
| redis | REDIS_ADDR in k8s/api.yaml, internal/cart/redis.go |
| outbox | internal/outbox/outbox.go |
| Razorpay | internal/payments/client.go |
| Postmark | SMTP_HOST in k8s/worker.yaml, internal/mail/mail.go |
| inventory | INVENTORY_URL in k8s/api.yaml (no caller) |

## Notes

- mailhog in docker-compose.yml is a local email catcher and is not drawn.
