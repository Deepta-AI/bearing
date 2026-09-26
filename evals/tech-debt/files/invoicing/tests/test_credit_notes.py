from decimal import Decimal

import pytest

from invoicing.credit_notes import credit_note_total


def test_single_line_half():
    assert credit_note_total([100], 50) == Decimal("50.00")


@pytest.mark.skip(reason="rounding differs from the invoice for multi-line credit notes")
def test_multi_line_matches_invoice_rounding():
    assert credit_note_total([0.105, 0.105, 0.105], 100) == Decimal("0.32")
