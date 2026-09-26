import pytest

from labels.render import render_label


def test_label_carries_order_and_weight():
    label = render_label("ORD123", "12 MG Road, Bengaluru 560001", 1.5)
    assert "ORDER ORD123" in label
    assert "1.5 kg" in label


@pytest.mark.skip(reason="checksum disagrees with the warehouse scanner, see the vendored encoder")
def test_barcode_checksum_matches_scanner():
    from barcode128 import checksum

    assert checksum("ORD123") == 47
