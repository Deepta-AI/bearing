import os

import pytest

pytestmark = pytest.mark.integration


@pytest.fixture
def conn():
    url = os.environ.get("DATABASE_URL")
    if not url:
        pytest.skip("DATABASE_URL not set")
    psycopg = pytest.importorskip("psycopg")
    with psycopg.connect(url) as c:
        yield c


def test_tc_0235_single_use_coupon_redeemed_once(conn):
    from shop.redemptions import AlreadyRedeemed, redeem

    redeem(conn, "cus_1", "WELCOME")
    with pytest.raises(AlreadyRedeemed):
        redeem(conn, "cus_1", "WELCOME")


def test_tc_0236_two_customers_can_redeem_same_code(conn):
    from shop.redemptions import redeem

    redeem(conn, "cus_1", "WELCOME")
    redeem(conn, "cus_2", "WELCOME")
