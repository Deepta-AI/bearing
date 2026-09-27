from datetime import date

from app.flags import Flag, Flags, load_overrides


def test_missing_is_off():
    f = Flags.from_env({})
    assert not any(f.enabled(x) for x in Flag)


def test_only_true_is_on():
    f = Flags.from_env({"FLAG_BULK_INVOICE_DOWNLOAD": "true", "FLAG_NEW_PRICING": "false"})
    assert f.enabled(Flag.BULK_INVOICE_DOWNLOAD)
    assert not f.enabled(Flag.NEW_PRICING)


def test_live_override_wins_and_expired_is_ignored():
    overrides = {
        "a": [{"flag": "bulk_invoice_download", "on": True, "until": "2026-10-01"}],
        "b": [{"flag": "bulk_invoice_download", "on": True, "until": "2026-09-01"}],
    }
    base = Flags.from_env({})
    today = date(2026, 9, 15)
    assert base.for_account("a", overrides, today).enabled(Flag.BULK_INVOICE_DOWNLOAD)
    assert not base.for_account("b", overrides, today).enabled(Flag.BULK_INVOICE_DOWNLOAD)
    assert not base.for_account("c", overrides, today).enabled(Flag.BULK_INVOICE_DOWNLOAD)


def test_overrides_file_loads_for_every_account():
    data = load_overrides()
    for account in data:
        Flags.from_env({}).for_account(account, data, date(2026, 1, 1))
