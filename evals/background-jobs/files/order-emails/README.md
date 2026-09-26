# order-emails

The checkout service for the shop. Orders are stored in SQLite through
the built-in `node:sqlite` module (schema in src/db.js). After an order is
placed the customer gets a confirmation email through the SMTP relay.

Production runs 2 replicas of the web process (deploy/k8s.yaml), sharing
one database file on a volume. The SMTP relay answers in about 1 s at p99
on a normal day but has stalled for the full 60 s client timeout during
its maintenance windows, which is when checkout requests time out.

No npm dependencies; Node 22.5 or later.

    make check    # node --test (every test/*.test.js)
