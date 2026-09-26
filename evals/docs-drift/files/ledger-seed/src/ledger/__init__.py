"""A tiny double-entry ledger."""


def balance(entries):
    return sum(e["cents"] for e in entries)
