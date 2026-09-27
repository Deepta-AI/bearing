# Event sheet

Last reviewed: 2026-06-30.

| Event | Fires when (layer) | Properties | Platforms |
| --- | --- | --- | --- |
| `screen_viewed` | the router or navigator shows a screen (client) | `screen: enum(home,product,cart,checkout,order_confirmation)` | web, mobile |
| `signed_up` | the account row is created (server) | `method: enum(email,phone)` | server |
| `product_viewed` | the product page or screen opens (client) | `product_id: string`; `category: string(40)` | web, mobile |
| `product_added_to_cart` | the add button succeeds (client) | `product_id: string`; `quantity: integer`; `price_minor: integer`; `currency: enum(INR)` | web, mobile |
| `cart_viewed` | the cart page or screen opens (client) | `item_count: integer`; `cart_value_minor: integer` | web, mobile |
| `checkout_started` | the shopper presses Checkout in the cart (client) | `cart_value_minor: integer`; `currency: enum(INR)`; `item_count: integer` | web, mobile |
| `coupon_applied` | the server accepts a coupon code (client, on the response) | `coupon_code: string(20)`; `discount_minor: integer` | web, mobile |
| `payment_submitted` | the shopper submits the payment form (client) | `method: enum(card,upi,cod)` | web, mobile |
| `order_placed` | the order is committed (server) | `order_id: string`; `value_minor: integer`; `currency: enum(INR)`; `is_first_order: boolean` | server |
| `order_cancelled` | an order moves to cancelled (server) | `order_id: string`; `reason: enum(customer,stock,payment)` | server |
