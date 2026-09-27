# invoice-service

Invoices for the billing team: storage, a small CLI and the reports the
accountants pull at month end. Python 3.12, standard library only; tests
use pytest.

    make check        # the gate: tests
    python -m invoices list      # print every invoice

Money is stored and passed around as integer paise (see
docs/adr/0004-money-as-integer-paise.md).

Tickets live in the PAY project of the team tracker (ids look like PAY-301).
See CONTRIBUTING.md for branches and commits.
