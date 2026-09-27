import pytest

from maintdesk.payouts import pay_vendor


def test_payouts_not_built_yet():
    with pytest.raises(NotImplementedError):
        pay_vendor(1, 150000, "job-1")
