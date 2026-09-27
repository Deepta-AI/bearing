# 0002 Refund reason codes live in code

Status: Accepted (2026-06-10)

The list changes a few times a year and every change needs a support-tool
release anyway, so the codes are a dict in `refunds/reasons.py`, not a table.
