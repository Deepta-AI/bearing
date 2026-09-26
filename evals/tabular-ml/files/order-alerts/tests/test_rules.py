from alerts.rules import check


def test_normal_hour_is_quiet():
    assert check("2026-09-01T13:00", 700) is None


def test_collapse_pages():
    assert check("2026-09-01T13:00", 40) is not None
