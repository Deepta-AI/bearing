from datetime import date

import pytest

from invoices.models import Invoice
from invoices.store import InvoiceStore, sample_store


def test_all_is_sorted_by_date_then_number():
    numbers = [i.number for i in sample_store().all()]
    assert numbers == ["INV-1001", "INV-1002", "INV-1003", "INV-1004"]


def test_duplicate_number_is_refused():
    store = InvoiceStore()
    store.add(Invoice("INV-1", "A", date(2026, 8, 1), 100))
    with pytest.raises(ValueError):
        store.add(Invoice("INV-1", "B", date(2026, 8, 2), 200))


def test_get_unknown_raises():
    with pytest.raises(KeyError):
        sample_store().get("INV-9")
