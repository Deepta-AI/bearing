# Event sheet

Events this service sends. The pipeline drops any event not listed here.

| Event | Trigger | Properties | Owner |
|---|---|---|---|
| order_viewed | GET /v1/orders/{id} returns 200 | order_id, status | Growth |
