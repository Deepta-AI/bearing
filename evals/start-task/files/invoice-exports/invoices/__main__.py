import sys

from .store import sample_store


def main(argv: list[str]) -> int:
    if not argv or argv[0] != "list":
        print("usage: python -m invoices list", file=sys.stderr)
        return 2
    for inv in sample_store().all():
        print(f"{inv.number}\t{inv.customer}\t{inv.issued_on}\t{inv.amount_paise}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
