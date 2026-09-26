"""Customer email through the mail relay. A sent email cannot be recalled."""

from typing import Protocol

from app.store import Store


class Mailer(Protocol):
    def send(self, to: str, subject: str, body: str) -> str: ...


def email_customer(store: Store, mailer: Mailer, customer_id: str, subject: str, body: str) -> str:
    return mailer.send(store.get_customer(customer_id).email, subject, body)
