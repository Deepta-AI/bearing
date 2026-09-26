"""Client for the HR system. Only the calls the People tools use."""

from dataclasses import dataclass


@dataclass(frozen=True)
class Employee:
    employee_id: str
    country: str  # "IN" or "UK"
    grade: str  # "G1" .. "G7"


class HRISClient:
    def __init__(self, base_url: str, token: str):
        self.base_url = base_url
        self.token = token

    def employee(self, slack_user_id: str) -> Employee:
        raise NotImplementedError("calls GET /employees/by-slack/{id}")

    def leave_balance(self, employee_id: str) -> dict:
        """Returns {"earned": float, "sick": float, "optional_holidays": int}."""
        raise NotImplementedError("calls GET /employees/{id}/leave-balance")
