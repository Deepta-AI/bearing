"""Members store. Holds only what ADR-0003 allows: phone number and first name."""

from dataclasses import dataclass, field


@dataclass
class Member:
    phone: str
    first_name: str
    points: int = 0
    history: list = field(default_factory=list)


class MemberStore:
    def __init__(self):
        self._by_phone = {}

    def enrol(self, phone, first_name):
        if phone in self._by_phone:
            return self._by_phone[phone]
        m = Member(phone=phone, first_name=first_name)
        self._by_phone[phone] = m
        return m

    def get(self, phone):
        return self._by_phone.get(phone)
