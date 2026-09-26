from app.summarise import build_messages


def test_messages_have_system_and_ticket():
    msgs = build_messages("Printer offline since Monday.")
    assert msgs[0]["role"] == "system" and msgs[1]["content"] == "Printer offline since Monday."
