"""Runs against a real Postgres. Skipped unless DATABASE_URL is set; apply
the migrations first (make migrate)."""

import os
import uuid

import pytest

pytestmark = pytest.mark.integration

DSN = os.environ.get("DATABASE_URL")


@pytest.fixture
def ledger():
    if not DSN:
        pytest.skip("DATABASE_URL not set")
    pytest.importorskip("psycopg")
    from ledger.accounts import PostgresLedger

    ledger = PostgresLedger(DSN)
    yield ledger
    ledger.conn.close()


def test_posting_is_idempotent_by_reference(ledger):
    ref = f"it-{uuid.uuid4()}"
    cash, revenue = f"cash-{ref}", f"revenue-{ref}"
    ledger.open(cash)
    ledger.open(revenue)
    posting_lines = [(cash, 2500), (revenue, -2500)]
    from ledger.accounts import Posting

    assert ledger.post(Posting(ref, posting_lines))
    assert not ledger.post(Posting(ref, posting_lines))
    assert ledger.balance(cash) == 2500


def test_line_for_unknown_account_rolls_back(ledger):
    import psycopg

    from ledger.accounts import Posting

    ref = f"it-{uuid.uuid4()}"
    with pytest.raises(psycopg.errors.ForeignKeyViolation):
        ledger.post(Posting(ref, [(f"missing-{ref}", 100), (f"other-{ref}", -100)]))
    assert ledger.balance(f"missing-{ref}") == 0
