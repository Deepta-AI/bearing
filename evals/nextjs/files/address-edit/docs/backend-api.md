# Commerce API (the parts the storefront uses)

Base URL `API_URL`. Every call sends `Authorization: Bearer <API_TOKEN>`,
the storefront's service token. The token can read and write every
customer's data: the API does not know which customer is signed in to the
storefront. Scoping a request to the signed-in customer is the
storefront's job.

## Customers

- `GET /customers/{customerId}` returns `{ id, name, email }`.
- `PATCH /customers/{customerId}` with `{ name }` returns the customer.

## Addresses

- `GET /customers/{customerId}/addresses` returns
  `{ items: Address[] }`.
- `GET /addresses/{addressId}` returns one `Address`, whoever owns it.
- `PATCH /addresses/{addressId}` with any of `{ line1, line2, city,
  state, pin, phone }` returns the updated `Address`. It does not check
  which customer the address belongs to, and it never changes `country`.
- `DELETE /addresses/{addressId}` is not used by the storefront yet.

`Address` is `{ id, customerId, label, line1, line2, city, state, pin,
country, phone }`; `line2` may be null.

Errors: `404` unknown id, `422` with `{ errors: { field: message } }` on
invalid input, `5xx` otherwise.
