#!/usr/bin/env bash
# Builds this fixture's history in place: a team repository on main, one
# commit behind origin/main (the ADR-0005 acceptance was fetched, not pulled),
# with task branches on origin and in this clone as they stood after the last
# fetch (27 Sep). Run from the fixture copy; it removes
# itself and its stages.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
S=.eval-stages
who() { export GIT_AUTHOR_NAME="$1" GIT_AUTHOR_EMAIL="$2" GIT_COMMITTER_NAME="$1" GIT_COMMITTER_EMAIL="$2"; }
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
stage() { cp -R "$S/$1/." .; git add -A; }
commit() { at "$1"; git commit -q -m "$2"; }

git init -q -b main
echo "$S/" >> .git/info/exclude
git remote add origin git@code.example.internal:bookings/bookings-api.git

who "Dev Two" dev.two@example.com
git add -A; commit "2026-08-01T10:00:00" "feat(bookings): book and cancel slots"
stage bk090; commit "2026-08-11T16:00:00" "chore(BK-090): progress record, merged in !31"
# BK-099: pushed once by Dev Four, never touched again.
who "Dev Four" dev.four@example.com
git checkout -q -b feature/BK-099-rate-limit
stage bk099; commit "2026-08-20T18:45:00" "wip(BK-099): token bucket skeleton"
git update-ref refs/remotes/origin/feature/BK-099-rate-limit HEAD
git checkout -q main; git branch -q -D feature/BK-099-rate-limit

who "Dev Three" dev.three@example.com
stage bk095; commit "2026-08-28T12:10:00" "chore(BK-095): recurring bookings abandoned, see ticket"

# BK-101: opened as !42, merged on 16 Sep; its record was never updated.
who "Dev One" dev.one@example.com
git checkout -q -b feature/BK-101-cancellation-fee
stage bk101; commit "2026-09-09T11:30:00" "feat(fees): cancellation fee inside 24 hours [BK-101]"
git update-ref refs/remotes/origin/feature/BK-101-cancellation-fee HEAD
git checkout -q main

who "Dev Two" dev.two@example.com
stage adr5p; commit "2026-09-10T15:00:00" "docs(adr): propose ADR-0005, SMS provider"

# BK-104: this clone checked it out on 12 Sep; Dev Two pushed more on 18 Sep.
git checkout -q -b feature/BK-104-sms-reminders
stage bk104a; commit "2026-09-12T10:20:00" "feat(reminders): due-time calculation [BK-104]"
stage bk104b; commit "2026-09-18T17:40:00" "chore(BK-104): blocked on the SMS provider decision"
git update-ref refs/remotes/origin/feature/BK-104-sms-reminders HEAD
git reset -q --hard HEAD~1
git checkout -q main

at "2026-09-16T12:00:00"
git merge -q --no-ff feature/BK-101-cancellation-fee -m "Merge branch 'feature/BK-101-cancellation-fee' into 'main'

Cancellation fee inside 24 hours [BK-101]

See merge request bookings/bookings-api!42"

# BK-110: pushed by Dev Five, no progress record.
who "Dev Five" dev.five@example.com
git checkout -q -b feature/BK-110-invoice-pdf
stage bk110; commit "2026-09-22T14:05:00" "feat(invoices): invoice lines per clinic and month [BK-110]"
git update-ref refs/remotes/origin/feature/BK-110-invoice-pdf HEAD
git checkout -q main; git branch -q -D feature/BK-110-invoice-pdf

who "Dev Two" dev.two@example.com
stage adr5a; commit "2026-09-24T16:30:00" "docs(adr): accept ADR-0005, provider B"
git update-ref refs/remotes/origin/main main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
# This clone fetched but never pulled: local main stops before the ADR.
git reset -q --hard HEAD~1

# BK-107: this clone's own work, not pushed yet.
who "Dev One" dev.one@example.com
git checkout -q -b feature/BK-107-waitlist
stage bk107; commit "2026-09-25T19:15:00" "feat(waitlist): add and list [BK-107]"
git checkout -q main

git branch -q --set-upstream-to=origin/main main
git branch -q -u origin/feature/BK-101-cancellation-fee feature/BK-101-cancellation-fee
git branch -q -u origin/feature/BK-104-sms-reminders feature/BK-104-sms-reminders
rm -rf "$S"
sed -i '/^\.eval-stages\/$/d' .git/info/exclude
