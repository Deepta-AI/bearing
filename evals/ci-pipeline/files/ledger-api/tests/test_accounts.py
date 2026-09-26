import pytest

from ledger.accounts import MemoryLedger, Posting, UnbalancedPosting


def ledger_with(*accounts):
    ledger = MemoryLedger()
    for account in accounts:
        ledger.open(account)
    return ledger


def test_balanced_posting_moves_money():
    ledger = ledger_with("cash", "revenue")
    assert ledger.post(Posting("inv-1", [("cash", 5000), ("revenue", -5000)]))
    assert ledger.balance("cash") == 5000
    assert ledger.balance("revenue") == -5000


def test_repeated_reference_is_applied_once():
    ledger = ledger_with("cash", "revenue")
    posting = Posting("inv-2", [("cash", 700), ("revenue", -700)])
    assert ledger.post(posting)
    assert not ledger.post(posting)
    assert ledger.balance("cash") == 700


def test_unbalanced_posting_is_rejected():
    ledger = ledger_with("cash", "revenue")
    with pytest.raises(UnbalancedPosting):
        ledger.post(Posting("inv-3", [("cash", 700), ("revenue", -600)]))
    assert ledger.balance("cash") == 0


def test_unknown_account_changes_nothing():
    ledger = ledger_with("cash")
    with pytest.raises(KeyError):
        ledger.post(Posting("inv-4", [("cash", 100), ("nowhere", -100)]))
    assert ledger.balance("cash") == 0
