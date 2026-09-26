"""Covers CLM-5 (employee emails) and CLM-10 (manager emails)."""

from datetime import date

from claimdesk.models import Claim, User
from claimdesk.notify import email_employee, email_manager

OWNER = User(10, "Ravi", "ravi@example.com", manager_id=3)
MANAGER = User(3, "Meena", "meena@example.com")


def claim(**kw):
    return Claim(id=7, owner_id=10, spent_on=date(2026, 9, 1), amount_inr=4500,
                 category="travel", description="Train", **kw)


def outbox():
    sent = []
    return sent, lambda **m: sent.append(m)


def test_clm5_rejection_email_carries_the_reason():
    sent, send = outbox()
    email_employee(send, OWNER, claim(status="rejected", reject_reason="duplicate"), "rejected")
    assert sent[0]["to"] == "ravi@example.com"
    assert "Reason: duplicate" in sent[0]["body"]


def test_clm5_paid_email():
    sent, send = outbox()
    email_employee(send, OWNER, claim(status="paid"), "paid")
    assert sent[0]["subject"] == "Your claim #7 was paid"


def test_clm10_manager_is_told_a_claim_waits():
    sent, send = outbox()
    email_manager(send, MANAGER, OWNER, claim(status="submitted"))
    assert sent[0]["to"] == "meena@example.com"
