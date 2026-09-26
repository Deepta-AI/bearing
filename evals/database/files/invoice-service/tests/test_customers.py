import pytest

from app.db.customer_repo import CustomerRepo
from app.db.errors import DuplicateKey
from tests.fakes import FakeConn


class _Diag:
    constraint_name = "customers_tenant_email_key"


class _UniqueViolation(Exception):
    sqlstate = "23505"
    diag = _Diag()


def test_duplicate_email_is_translated():
    conn = FakeConn(results=[_UniqueViolation("dup")])
    with pytest.raises(DuplicateKey) as err:
        CustomerRepo(conn).insert(7, "Ana", "ana@example.com")
    assert err.value.constraint == "customers_tenant_email_key"
