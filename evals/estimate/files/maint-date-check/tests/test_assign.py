import pytest

from maintdesk.assign import AssignError, assign_vendor
from maintdesk.models import Store, Vendor
from maintdesk.requests import file_request


def setup():
    s = Store()
    s.add_vendor(Vendor(1, "Asha Plumbing", "plumber", "+919811111111"))
    r = file_request(s, 7, "+919800000001", "Kitchen tap leaks all night")
    return s, r


def test_assign_sends_sms():
    s, r = setup()
    sent = []
    assign_vendor(s, r.id, 1, sms=lambda p, b: sent.append((p, b)))
    assert r.status == "assigned"
    assert sent and sent[0][0] == "+919811111111"


def test_cannot_assign_twice():
    s, r = setup()
    assign_vendor(s, r.id, 1, sms=lambda p, b: None)
    with pytest.raises(AssignError):
        assign_vendor(s, r.id, 1, sms=lambda p, b: None)
