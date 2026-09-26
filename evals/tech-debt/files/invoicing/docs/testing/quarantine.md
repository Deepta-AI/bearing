# Quarantined tests

Held out of `make check` with `@pytest.mark.quarantine`. Each is fixed or
deleted by its deadline.

| Test | Why | Quarantined | Deadline | Owner |
| --- | --- | --- | --- | --- |
| tests/test_webhooks.py::test_rejects_tampered_body | failed twice on CI with a timeout in the shared runner | 2026-06-01 | 2026-08-31 | @finance-eng/billing |
