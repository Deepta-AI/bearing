#!/usr/bin/env bash
# Builds this fixture's history: employees at larkspur.dev wrote the
# library from March 2024; two outside contractors contributed, Jordan Lee
# (two commits, assignment on file in docs/legal/ip-assignments.md) and
# Sam Ortiz (one commit, the checksum package, no assignment on file).
# The files on disk are the final working tree.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
who() { export GIT_AUTHOR_NAME="$1" GIT_AUTHOR_EMAIL="$2" GIT_COMMITTER_NAME="$1" GIT_COMMITTER_EMAIL="$2"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do mkdir -p "$(dirname "$p")"; cp -a "$final/$p" "$p"; done; }
rm -rf internal cmd docs third_party window.go window_test.go

git init -q -b main
who "Dev One" "dev.one@larkspur.dev"; at "2024-03-04 10:00:00"
restore go.mod Makefile LICENSE README.md third_party/ringbuf/ringbuf.go
cat > window.go <<'GO'
// Copyright (c) 2024 Larkspur Systems Private Limited. All rights reserved.
// Confidential and proprietary. Not for distribution outside Larkspur.

// Package tallyq counts events in a sliding time window.
package tallyq
GO
git add -A; git commit -q -m "Start tallyq with a vendored ring buffer"

who "Jordan Lee" "jordan.lee@contractmail.test"; at "2024-11-06 15:20:00"
restore window.go window_test.go
sed -i '/internal\/checksum/d; /^\/\/ Snapshot returns/,$d' window.go
sed -i 's/^\t"encoding\/binary"$//' window.go
sed -i '/^func TestSnapshotChecksumIsStable/,$d' window_test.go
gofmt -w window.go 2>/dev/null || true
git add -A; git commit -q -m "Sliding window with per-slot buckets"

at "2024-11-19 11:45:00"
restore cmd/tallyq/main.go
git add -A; git commit -q -m "Add the tallyq command"

who "Sam Ortiz" "sam.ortiz@freelancer.test"; at "2025-04-08 18:10:00"
restore internal/checksum/crc.go internal/checksum/crc_test.go window.go window_test.go
git add -A; git commit -q -m "Checksum snapshots with CRC-32"

who "Dev Two" "dev.two@larkspur.dev"; at "2025-06-30 09:40:00"
restore docs/legal/ip-assignments.md
git add -A; git commit -q -m "Record contractor IP assignments"

git remote add origin git@git.larkspur.dev:larkspur/tallyq.git
rm -r "$final"
