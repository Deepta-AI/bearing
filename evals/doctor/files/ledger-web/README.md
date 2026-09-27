# ledger-web

Journal-entry API for the finance team: accepts double-entry postings and
stores them in Postgres.

    make setup   # once per clone: git hooks
    npm install  # husky and lint-staged
    make dev     # needs DATABASE_URL, see .env.example
    make check   # lint and tests, the gate
