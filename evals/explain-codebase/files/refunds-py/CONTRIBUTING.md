# Contributing

- Tests live in `tests/` and are named `test_<module>.py`.
- Errors: raise a `RefundError` subclass from the service layer; handlers
  turn them into HTTP errors. Never return None to signal failure.
- Logging: use `refunds.log.get()`, never `print`.
- Money is always an integer number of paise.
