"""Emails about claims. Delivery goes through the company SMTP relay; the
sender is injected so tests and the web app can pass their own."""

from .models import Claim, User

EMPLOYEE_SUBJECTS = {
    "approved": "Your claim #{id} was approved",
    "rejected": "Your claim #{id} was rejected",
    "paid": "Your claim #{id} was paid",
}


def email_employee(send, owner: User, claim: Claim, event: str) -> None:
    """CLM-5: tell the employee their claim was approved, rejected or paid."""
    subject = EMPLOYEE_SUBJECTS[event].format(id=claim.id)
    body = f"Amount: INR {claim.amount_inr:,}\n"
    if event == "rejected" and claim.reject_reason:
        body += f"Reason: {claim.reject_reason}\n"
    send(to=owner.email, subject=subject, body=body)


def email_manager(send, manager: User, owner: User, claim: Claim) -> None:
    """CLM-10: tell the manager a claim is waiting for their decision."""
    subject = f"Claim #{claim.id} from {owner.name} is waiting for you"
    send(to=manager.email, subject=subject, body=f"Amount: INR {claim.amount_inr:,}\n")
