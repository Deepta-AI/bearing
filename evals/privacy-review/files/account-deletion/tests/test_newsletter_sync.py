from app.accounts import sign_up
from app.newsletter import FakeMailBlast
from jobs.sync_newsletter import sync


def test_sync_pushes_opted_in_users_only(db):
    sign_up(db, "in@example.com", "In", "pw-12345", marketing_opt_in=True)
    sign_up(db, "out@example.com", "Out", "pw-12345", marketing_opt_in=False)
    client = FakeMailBlast()
    assert sync(db, client) == 1
    assert list(client.contacts) == ["in@example.com"]
