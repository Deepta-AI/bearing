#!/usr/bin/env bash
# Builds the workspace in place: this folder is the payments group's
# manifest repository (main), and ledger-api and statements-worker are
# separate repositories cloned beside its files, each with its own history
# and an origin on the group's GitLab. The manifest's .gitignore keeps them
# (and finance-drop/) out of its own history. Run from the fixture copy; it
# removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }

for r in ledger-api statements-worker; do
  (
    cd "$r"
    git init -q -b main
    git remote add origin "git@gitlab.larkspur.example:payments/$r.git"
    git add -A
    at "2026-09-18T10:00:00"; git commit -q -m "PAY-230: $r as deployed"
    git update-ref refs/remotes/origin/main main
  )
done

git init -q -b main
git remote add origin git@gitlab.larkspur.example:payments/payments-workspace.git
git add -A
at "2026-09-20T09:30:00"; git commit -q -m "PAY-233: retire payout-recon notebooks; conventions for data handling"
git update-ref refs/remotes/origin/main main

# An open merge request from a colleague: it registers settlement-api and
# takes the next port. It is fetched (origin/...) but not merged into main.
export GIT_AUTHOR_NAME="Dev Two" GIT_AUTHOR_EMAIL="dev.two@example.com"
export GIT_COMMITTER_NAME="Dev Two" GIT_COMMITTER_EMAIL="dev.two@example.com"
git checkout -q --detach
cat >> repos.yaml <<'YAML'
  - name: settlement-api
    lang: go
    kind: service
    port: 8105
    owners: "@payments/backend"
YAML
git add repos.yaml
at "2026-09-25T16:10:00"; git commit -q -m "PAY-240: register settlement-api on port 8105"
git update-ref refs/remotes/origin/PAY-240-register-settlement-api HEAD
git checkout -q main
