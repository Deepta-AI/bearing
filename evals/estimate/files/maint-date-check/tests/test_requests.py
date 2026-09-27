import pytest

from maintdesk.models import Store
from maintdesk.requests import InvalidRequest, file_request, status_for_tenant


def test_file_request_opens_it():
    s = Store()
    r = file_request(s, 7, "+919800000001", "Kitchen tap leaks all night")
    assert r.status == "open"


def test_short_description_refused():
    with pytest.raises(InvalidRequest):
        file_request(Store(), 7, "+919800000001", "leak")


def test_tenant_sees_only_own_request():
    s = Store()
    r = file_request(s, 7, "+919800000001", "Kitchen tap leaks all night")
    assert status_for_tenant(s, r.id, "+919800000001")["status"] == "open"
    assert status_for_tenant(s, r.id, "+919800000002") is None
