from app.triage.rules import route
from app.crm import account_tier


def test_password_goes_to_account_access():
    assert route("Can't log in", "I reset my password twice") == "account_access"


def test_no_match_goes_to_general():
    assert route("Question", "Hello, a quick question about your roadmap") == "general"


def test_enterprise_domain():
    assert account_tier("ap@kestrel-freight.example") == "enterprise"
    assert account_tier("someone@smallshop.example") == "standard"
