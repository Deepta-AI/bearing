from typing import Protocol


class Mailer(Protocol):
    def send(self, to: str, subject: str, body: str) -> str:
        """Sends immediately through the relay. Cannot be recalled."""
        ...
