# shopfront

The checkout service for the web store. A small Python service: `shopfront/checkout.py`
takes a cart and places the order through a pooled database connection
(`shopfront/db.py`). Settings ship with the code in `shopfront/settings.py`.

Production runs three pods, four worker processes per pod, behind the API
gateway. Releases are git tags (`vX.Y.Z`); the deploy bot rolls a tag out to
all pods and posts in the deploy channel.

## Working on it

    make check    # the tests

## Operations

- Runbooks: `docs/runbooks/`
- Incidents and postmortems: `docs/postmortems/`
- Tasks are tracked as `SHOP-<n>`.
