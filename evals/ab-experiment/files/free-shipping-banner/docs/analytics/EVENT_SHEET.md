# Event sheet

| Event | Fired when | Properties | Owner |
| --- | --- | --- | --- |
| `product_viewed` | a product page or screen is rendered | device_id, platform, product_id | web, app |
| `experiment_exposed` | the visitor is counted into an experiment | experiment, variant, device_id, platform | web, app |
| `order_placed` | an order is confirmed | device_id, platform, order_id, total | checkout |
| `order_refunded` | a refund is issued | device_id, order_id, amount | payments |
