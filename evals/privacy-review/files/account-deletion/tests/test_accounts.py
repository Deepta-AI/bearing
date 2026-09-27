from app.accounts import delete_account, log_in, sign_up


def test_sign_up_and_log_in(db):
    uid = sign_up(db, "asha@example.com", "Asha Rao", "pw-12345")
    assert log_in(db, "asha@example.com", "pw-12345", "203.0.113.7") == uid


def test_wrong_password_is_refused(db):
    sign_up(db, "asha@example.com", "Asha Rao", "pw-12345")
    assert log_in(db, "asha@example.com", "nope", "203.0.113.7") is None


def test_deleted_user_cannot_log_in(db):
    uid = sign_up(db, "asha@example.com", "Asha Rao", "pw-12345")
    assert delete_account(db, uid) is True
    assert log_in(db, "asha@example.com", "pw-12345", "203.0.113.7") is None
