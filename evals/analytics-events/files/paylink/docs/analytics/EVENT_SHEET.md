# Event sheet

One row per event. Properties are separated by semicolons; types are
`string`, `integer`, `boolean` or `enum(a,b,...)`. Amounts are integers in
minor units with a `currency`. src/shared/events.js mirrors this table and
test/catalogue.test.js keeps them equal.

| Event | Fires when (layer) | Properties | Platforms | Owner | Destination |
| --- | --- | --- | --- | --- | --- |
| `screen_viewed` | the router shows a page (web) | `screen: enum(invoices,invoice_preview,pay,settings)` | web | growth | product, warehouse |
| `consent_updated` | the merchant answers the consent banner (web) | `analytics: boolean` | web | growth | product |
| `signed_up` | the account row is created (server) | `plan: enum(free,pro)` | server | growth | product, warehouse |
| `logged_in` | the session is created (server) | `method: enum(password,magic_link)` | server | growth | product |
| `invoice_created` | POST /api/invoices succeeds (server) | `invoice_id: string`; `currency: enum(INR,USD)`; `amount_minor: integer`; `line_count: integer` | server | invoicing | product, warehouse |
| `invoice_sent` | the merchant presses Send and the API accepts it (web) | `invoice_id: string`; `channel: enum(email,link)` | web | invoicing | product, warehouse |
