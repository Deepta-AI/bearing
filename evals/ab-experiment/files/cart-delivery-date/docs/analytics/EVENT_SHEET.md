# Event sheet

One row per event the storefront sends. `user_id` is null for visitors who
are not signed in; `device_id` is a first-party cookie that lives for a year.
Around 70% of mobile cart viewers are not signed in.

| Event | Fired when | Properties | Owner |
| --- | --- | --- | --- |
| `cart_viewed` | the cart page is rendered | user_id, device_id, platform | web |
| `checkout_started` | the checkout page is rendered | user_id, device_id, platform | web |
| `checkout_completed` | the order is confirmed | user_id, device_id, platform, order_id, total | web |
| `payment_failed` | the payment provider declines or errors | user_id, device_id, platform, reason | payments |
| `experiment_exposed` | a flag is evaluated for a request | experiment, variant, session_id | web |
