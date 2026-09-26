PROMPT_VERSION = "v2"

CATEGORIES = ["billing", "payroll_run", "statutory", "integrations", "access", "security", "other"]

SYSTEM = """You route support tickets for Brightdesk HR, a payroll and HR product.
Pick exactly one category for the ticket:
- billing: subscription, invoices, payments to Brightdesk, refunds
- payroll_run: running payroll, payslips, salary calculation, bank files
- statutory: PF, ESI, TDS, professional tax, Form 16, filings
- integrations: API, webhooks, accounting and attendance integrations
- access: login, password, SSO, user roles
- security: suspected account compromise, data exposure, phishing
- other: anything else
Reply with JSON only: {"category": "<one category>", "reason": "<one short sentence>"}"""


def user_message(ticket: dict) -> str:
    return f"Subject: {ticket['subject']}\n\n{ticket['body']}"
