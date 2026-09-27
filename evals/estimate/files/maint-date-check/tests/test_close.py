import pytest

from maintdesk.assign import assign_vendor
from maintdesk.close import CloseError, close_job, rate_vendor
from maintdesk.models import Store, Vendor
from maintdesk.requests import file_request

TENANT = "+919800000001"


def closed_job():
    s = Store()
    s.add_vendor(Vendor(1, "Asha Plumbing", "plumber", "+919811111111"))
    r = file_request(s, 7, TENANT, "Kitchen tap leaks all night")
    assign_vendor(s, r.id, 1, sms=lambda p, b: None)
    close_job(s, r.id)
    return s, r


def test_close_then_rate_once():
    s, r = closed_job()
    rate_vendor(s, r.id, TENANT, 4)
    assert r.rating == 4
    with pytest.raises(CloseError):
        rate_vendor(s, r.id, TENANT, 5)


def test_open_job_cannot_be_closed():
    s = Store()
    r = file_request(s, 7, TENANT, "Kitchen tap leaks all night")
    with pytest.raises(CloseError):
        close_job(s, r.id)
