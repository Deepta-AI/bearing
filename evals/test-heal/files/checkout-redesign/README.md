# storefront

Server-rendered checkout for the shop. Standard library only; tests use
pytest and a small DOM helper in tests/pages/dom.py that finds elements
the way a user would (role and name, label, test id).

    make check   # runs the pytest suite, which CI runs on every merge to main

Test case ids (TC-01xx) are in docs/testing/test-cases.md; each test's
docstring starts with its id.
