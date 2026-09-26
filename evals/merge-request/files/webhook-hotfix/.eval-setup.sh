#!/usr/bin/env bash
# Builds this fixture's git history in place: main, develop one feature
# ahead of main, and the hotfix branch under test four commits ahead of
# main, with remote-tracking refs for origin. The files on disk are the
# final tree of the hotfix branch; earlier versions are written here. Run
# from the fixture copy; it removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev Two" GIT_AUTHOR_EMAIL="dev.two@example.com"
export GIT_COMMITTER_NAME="Dev Two" GIT_COMMITTER_EMAIL="dev.two@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do cp "$final/$p" "$p"; done; }

# main: the service before the hotfix, without the SMS package (develop only).
mv internal/sms "$final/sms-develop"
sed -e 's#go test ./internal/webhook/...#go test ./...#' \
    -e '/replay tests are slow/d' "$final/Makefile" > Makefile
sed -e 's/, time.Now())/)/' -e '/^	"time"$/d' "$final/cmd/notifier/main.go" > cmd/notifier/main.go
sed -e 's/, d.Signature, time.Now())/, d.Signature)/' -e '/^	"time"$/d' \
    "$final/internal/replay/replay.go" > internal/replay/replay.go
cat > internal/webhook/verify.go <<'EOF'
// Package webhook verifies partner webhook signatures.
package webhook

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
)

var ErrBadSignature = errors.New("webhook: bad signature")

// Verify checks signature, the hex HMAC-SHA256 of "<timestamp>.<body>".
func Verify(secret []byte, timestamp string, body []byte, signature string) error {
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(timestamp + "."))
	mac.Write(body)
	if signature != hex.EncodeToString(mac.Sum(nil)) {
		return ErrBadSignature
	}
	return nil
}
EOF
cat > internal/webhook/verify_test.go <<'EOF'
package webhook

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"testing"
)

var secret = []byte("test-secret")

func sign(ts string, body []byte) string {
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(ts + "."))
	mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

const ts = "1790000000"

func TestVerifyLowercase(t *testing.T) {
	body := []byte(`{"event":"order.paid"}`)
	if err := Verify(secret, ts, body, sign(ts, body)); err != nil {
		t.Fatal(err)
	}
}

func TestRejectsTamperedBody(t *testing.T) {
	sig := sign(ts, []byte(`{"event":"order.paid"}`))
	if err := Verify(secret, ts, []byte(`{"event":"order.refunded"}`), sig); err != ErrBadSignature {
		t.Fatalf("got %v", err)
	}
}
EOF

git init -q -b main
git remote add origin git@github.com:example-org/notifier.git
git add -A
at "2026-09-02T09:30:00"; git commit -q -m "feat(webhook): verify partner webhook signatures [OPS-41]"
git update-ref refs/remotes/origin/main main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

git checkout -q -b develop
mv "$final/sms-develop" internal/sms
git add -A
at "2026-09-18T14:00:00"; git commit -q -m "feat(notify): order paid SMS [OPS-60]"
git update-ref refs/remotes/origin/develop develop

git checkout -q -b hotfix/webhook-uppercase-sig main
cat > internal/webhook/verify.go <<'EOF'
// Package webhook verifies partner webhook signatures.
package webhook

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
)

var ErrBadSignature = errors.New("webhook: bad signature")

// Verify checks signature, the hex HMAC-SHA256 of "<timestamp>.<body>".
func Verify(secret []byte, timestamp string, body []byte, signature string) error {
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(timestamp + "."))
	mac.Write(body)
	want := mac.Sum(nil)
	got, err := hex.DecodeString(signature)
	if err != nil {
		return ErrBadSignature
	}
	if !hmac.Equal(got, want) {
		return ErrBadSignature
	}
	return nil
}
EOF
cat > internal/webhook/verify_test.go <<'EOF'
package webhook

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"testing"
)

var secret = []byte("test-secret")

func sign(ts string, body []byte) string {
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(ts + "."))
	mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

const ts = "1790000000"

func TestVerifyLowercase(t *testing.T) {
	body := []byte(`{"event":"order.paid"}`)
	if err := Verify(secret, ts, body, sign(ts, body)); err != nil {
		t.Fatal(err)
	}
}

func TestVerifyUppercase(t *testing.T) {
	body := []byte(`{"event":"order.paid"}`)
	if err := Verify(secret, ts, body, strings.ToUpper(sign(ts, body))); err != nil {
		t.Fatal(err)
	}
}

func TestRejectsTamperedBody(t *testing.T) {
	sig := sign(ts, []byte(`{"event":"order.paid"}`))
	if err := Verify(secret, ts, []byte(`{"event":"order.refunded"}`), sig); err != ErrBadSignature {
		t.Fatalf("got %v", err)
	}
}
EOF
git add -A
at "2026-09-25T21:10:00"; git commit -q -m "fix(webhook): accept uppercase hex signatures"

grep -v -e 'log.Printf' -e '^	"log"$' "$final/internal/webhook/verify.go" > internal/webhook/verify.go
restore internal/webhook/verify_test.go internal/replay/replay.go cmd/notifier/main.go
git add -A
at "2026-09-25T21:40:00"; git commit -q -m "fix(webhook): reject stale timestamps"

restore internal/webhook/verify.go
git add -A
at "2026-09-25T22:05:00"; git commit -q -m "chore: debug logging for partner 401s"

restore Makefile
git add -A
at "2026-09-25T22:20:00"; git commit -q -m "chore(make): only run the webhook tests in check"
rm -r "$final"
