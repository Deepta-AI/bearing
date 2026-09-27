# 0001 Money is Decimal, never float

Status: Accepted (2026-03-02)

Amounts are `decimal.Decimal` quantized to the cent. Floats drift on sums of
many lines and have already produced a one paisa mismatch against the ledger.
