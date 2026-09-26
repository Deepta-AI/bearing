from app.labels import normalise


def test_normalise_known_label():
    assert normalise(" Refund_Request.\n") == "refund_request"


def test_unknown_label_is_other():
    assert normalise("shipping") == "other"
