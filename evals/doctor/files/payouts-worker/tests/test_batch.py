from payouts.batch import Balance, build_batch, payable


def test_holds_are_subtracted():
    assert payable(Balance("m1", 50_000, 5_000)) == 45_000


def test_small_balances_roll_over():
    assert payable(Balance("m2", 9_999, 0)) == 0


def test_batch_skips_zero_payouts():
    batch = build_batch([Balance("m1", 50_000, 0), Balance("m2", 100, 0)])
    assert batch == [("m1", 50_000)]
