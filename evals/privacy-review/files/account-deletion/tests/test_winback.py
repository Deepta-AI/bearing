from app.accounts import delete_account, sign_up
from app.newsletter import FakeMailBlast
from jobs.winback import run


def test_recently_closed_accounts_are_invited_back(db):
    uid = sign_up(db, "gone@example.com", "Gone Soon", "pw-12345")
    sign_up(db, "stays@example.com", "Stays", "pw-12345")
    delete_account(db, uid)
    client = FakeMailBlast()
    assert run(db, client) == 1
    assert list(client.contacts) == ["gone@example.com"]
