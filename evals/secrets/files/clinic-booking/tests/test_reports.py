from booking import reports


def test_signed_link_carries_expiry(monkeypatch):
    monkeypatch.setenv("REPORTS_SIGNING_KEY", "test-only-key")
    link = reports.signed_link("2026-09-01.csv", expires_in=60, now=1000)
    assert "expires=1060" in link and "sig=" in link
