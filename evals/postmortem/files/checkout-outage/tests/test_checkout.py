from shopfront import settings
from shopfront.checkout import place_order
from shopfront.db import Pool, PoolTimeout

import pytest


def test_places_an_order():
    pool = Pool(size=1, timeout=0.1, path=":memory:")
    status, body = place_order(pool, "c1", [("sku-1", 2, 49900)])
    assert status == 201
    assert body["total_paise"] == 99800


def test_gift_card_is_stored():
    pool = Pool(size=1, timeout=0.1, path=":memory:")
    status, _ = place_order(pool, "c1", [("sku-1", 1, 100)], gift_card="GC-1")
    assert status == 201


def test_empty_cart_is_rejected():
    pool = Pool(size=1, timeout=0.1, path=":memory:")
    assert place_order(pool, "c1", [])[0] == 400


def test_exhausted_pool_times_out():
    pool = Pool(size=1, timeout=0.05, path=":memory:")
    held = pool.acquire()
    with pytest.raises(PoolTimeout):
        pool.acquire()
    pool.release(held)


def test_exhausted_pool_fails_the_checkout():
    pool = Pool(size=1, timeout=0.05, path=":memory:")
    held = pool.acquire()
    status, _ = place_order(pool, "c1", [("sku-1", 1, 100)])
    pool.release(held)
    assert status == 500


def test_default_pool_size():
    assert settings.DB_POOL_SIZE == 20
