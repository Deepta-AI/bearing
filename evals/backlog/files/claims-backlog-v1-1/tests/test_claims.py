from datetime import date

import pytest

from claimdesk.claims import ClaimError, attach_receipt, decide, submit
from claimdesk.models import Claim, Receipt, User


OWNER = User(10, "Ravi", "ravi@example.com", manager_id=3)
MANAGER = User(3, "Meena", "meena@example.com")


def make_claim(amount=4500):
    return Claim(id=1, owner_id=10, spent_on=date(2026, 9, 1), amount_inr=amount,
                 category="travel", description="Cab to client office")


def pdf(size=1024):
    return Receipt("r.pdf", "application/pdf", size)


def test_receipt_over_limit_is_rejected():
    with pytest.raises(ClaimError):
        attach_receipt(make_claim(), pdf(11 * 1024 * 1024))


def test_submit_needs_a_receipt():
    with pytest.raises(ClaimError):
        submit(make_claim())


def test_small_claim_is_auto_approved():
    c = make_claim(amount=1999)
    attach_receipt(c, pdf())
    submit(c)
    assert c.status == "approved"


def test_claim_at_threshold_waits_for_a_decision():
    c = make_claim(amount=2000)
    attach_receipt(c, pdf())
    submit(c)
    assert c.status == "submitted"


def submitted():
    c = make_claim()
    attach_receipt(c, pdf())
    submit(c)
    return c


def test_manager_rejects_with_reason():
    c = submitted()
    decide(c, OWNER, MANAGER, False, "no receipt date")
    assert c.status == "rejected"
    assert c.reject_reason == "no receipt date"


def test_reject_needs_a_reason():
    with pytest.raises(ClaimError):
        decide(submitted(), OWNER, MANAGER, False, " ")


def test_only_the_manager_decides():
    other = User(4, "Kiran", "kiran@example.com", "finance_admin")
    with pytest.raises(ClaimError):
        decide(submitted(), OWNER, other, True)
