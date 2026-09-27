#!/usr/bin/env bash
# Starting state: a fresh clone (core.hooksPath unset, as every clone starts)
# whose owner committed a payout fix straight onto main. pre-push is
# committed without its executable bit.
set -eu
rm -f .eval-setup.sh
chmod +x .githooks/commit-msg .githooks/pre-commit .githooks/install.sh
chmod -x .githooks/pre-push
git init -q -b main
git add -A
git -c user.name=Dev -c user.email=dev@example.com commit -q -m "chore: payouts-worker on the team standard [PAY-88]"
printf '\n\ndef total(batch: list[tuple[str, int]]) -> int:\n    return sum(p for _, p in batch)\n' >> src/payouts/batch.py
git add -A
git -c user.name=Dev -c user.email=dev@example.com commit -q -m "fix: add batch total for the ops report"
