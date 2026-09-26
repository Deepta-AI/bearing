from app.slack_bot import handle_hr_command


def test_links_to_helpdesk():
    assert "hr-helpdesk" in handle_hr_command("how many sick days do I get", "U123")
