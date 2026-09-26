from app.mailer import render_digest


def test_render_digest_has_team_and_week():
    body = render_digest("payments", "2026-W38", "All good.")
    assert "payments" in body and "2026-W38" in body and "All good." in body
