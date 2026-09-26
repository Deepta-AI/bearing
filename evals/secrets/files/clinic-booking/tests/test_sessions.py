from booking import sessions

SECRET = "test-only-secret"


def test_round_trip():
    assert sessions.unsign(SECRET, sessions.sign(SECRET, "patient-7")) == "patient-7"


def test_tampered_cookie_is_rejected():
    cookie = sessions.sign(SECRET, "patient-7")
    assert sessions.unsign(SECRET, cookie.replace("patient-7", "patient-8")) is None
