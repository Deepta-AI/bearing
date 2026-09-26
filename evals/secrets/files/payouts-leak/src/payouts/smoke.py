"""Sandbox smoke test run by CI: one small payout against PAYGATE_BASE_URL."""

from payouts import config
from payouts.gateway import PayGate


def main():
    s = config.load()
    status = PayGate(s.paygate_base_url, s.paygate_secret_key).create_payout(
        "smoke-1", "SANDBOX-0001", 100
    )
    with open("smoke-report.txt", "w") as f:
        f.write(f"base_url={s.paygate_base_url} status={status}\n")


if __name__ == "__main__":
    main()
