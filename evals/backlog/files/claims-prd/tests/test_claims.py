from datetime import date

import pytest

from claimdesk.claims import ClaimError, attach_receipt, decide, submit
from claimdesk.models import Claim, Receipt, User


def make_claim(amount=1200):
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
    c = make_claim(amount=400)
    attach_receipt(c, pdf())
    submit(c)
    assert c.status == "approved"


def test_claim_over_threshold_waits_for_a_decision():
    c = make_claim(amount=1200)
    attach_receipt(c, pdf())
    submit(c)
    assert c.status == "submitted"


def test_finance_admin_rejects_with_reason():
    c = make_claim()
    attach_receipt(c, pdf())
    submit(c)
    decide(c, User(2, "Asha", "asha@example.com", "finance_admin"), False, "no receipt date")
    assert c.status == "rejected"
    assert c.reject_reason == "no receipt date"
