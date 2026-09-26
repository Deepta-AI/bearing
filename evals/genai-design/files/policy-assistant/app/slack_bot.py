"""Slack /hr command. Today it only links to the helpdesk form."""

HELPDESK_URL = "https://intranet.tallowbrook.example/hr-helpdesk"


def handle_hr_command(text: str, slack_user_id: str) -> str:
    return f"Please raise your question with the HR helpdesk: {HELPDESK_URL}"
