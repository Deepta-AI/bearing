"""Issue one invoice from the command line.

    python3 -m invoicing.cli --ledger sample/ledger.txt "SKU|Description|qty|unit_paise" ...
"""

import argparse

from invoicing import core


def last_issued(path):
    last = 0
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("INV-"):
                last = max(last, int(line.split()[0][4:]))
    return last


def main(argv=None):
    p = argparse.ArgumentParser(prog="invoicing")
    p.add_argument("--ledger", required=True)
    p.add_argument("--customer", default="Walk-in")
    p.add_argument("--region", default=core.DEFAULT_REGION)
    p.add_argument("items", nargs="*")
    args = p.parse_args(argv)

    # Continue the numbering from the ledger, not from 1.
    core._next_number = last_issued(args.ledger) + 1

    inv = core.Invoice(core.next_invoice_number(), args.customer, args.region)
    for text in args.items:
        inv.add(core.parse_line(text))
    print(core.render_text(inv))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
