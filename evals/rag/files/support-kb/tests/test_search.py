from kbot.search import search


def test_finds_sso_article():
    assert "account/sso-setup.md" in search("configure SSO with Okta")


def test_unknown_word_finds_nothing():
    assert search("zzqx") == []
