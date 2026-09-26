# payments-core

Order and payment handling for the storefront. Merchants sign in to the
dashboard; every API call carries a `Principal` (user, merchant, role) that
the gateway in front of this service has already authenticated.

- `payments/api.py` holds the handlers. Each returns `(status, body)`.
- `payments/orders.py` is the data access layer over SQLite.
- `payments/gateway.py` talks to the card gateway; tests use `FakeGateway`.
- `docs/api.md` is the public API reference for merchants' integrations.

Roles: `admin` and `support` act on their own merchant's orders; `viewer` is
read only. A user never sees another merchant's orders.

Money is stored and sent as integer paise (ADR-0002).

## Checks

    make check    # pytest
