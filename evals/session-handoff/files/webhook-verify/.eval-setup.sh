#!/usr/bin/env bash
# Builds this fixture's history. main is the released receiver (accepts
# everything). feature/PAY-157-webhook-verify has three commits; only the
# first was pushed, so the branch is two commits ahead of its upstream. The
# forwarding work (criterion 4) sits in a stash, a backoff helper for it sits
# on a local branch PAY-157-backoff that was never pushed, and the working
# tree is clean. The files on disk are the branch tip. Removes itself.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do mkdir -p "$(dirname "$p")"; cp "$final/$p" "$p"; done; }

# main: the receiver before PAY-157.
rm -rf internal docs/tasks
cat > cmd/receiver/main.go <<'GO'
package main

import (
	"log"
	"net/http"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /webhooks/payments", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK) // TODO: verify the signature (PAY-157)
	})
	log.Fatal(http.ListenAndServe(":8080", mux))
}
GO
git init -q -b main
git remote add origin git@gitlab.example.com:payments/webhook-receiver.git
git add -A
at "2026-09-01T12:00:00"; git commit -q -m "release: 0.3.0"
git update-ref refs/remotes/origin/main main

git checkout -q -b feature/PAY-157-webhook-verify
restore internal/webhook/verify.go internal/webhook/verify_test.go docs/tasks/PAY-157.md
git add -A
at "2026-09-18T16:30:00"; git commit -q -m "PAY-157: verify the provider signature"
git update-ref refs/remotes/origin/feature/PAY-157-webhook-verify HEAD
git branch -q --set-upstream-to=origin/feature/PAY-157-webhook-verify

# A side branch for the retry backoff, cut from the pushed commit, never pushed.
git checkout -q -b PAY-157-backoff
cat > internal/webhook/backoff.go <<'GO'
package webhook

import "time"

// Backoff is the wait before retry attempt n (1-based): 200ms, 400ms, 800ms.
func Backoff(n int) time.Duration {
	if n < 1 {
		n = 1
	}
	return 200 * time.Millisecond << (n - 1)
}
GO
cat > internal/webhook/backoff_test.go <<'GO'
package webhook

import (
	"testing"
	"time"
)

func TestBackoffDoubles(t *testing.T) {
	want := []time.Duration{200 * time.Millisecond, 400 * time.Millisecond, 800 * time.Millisecond}
	for i, w := range want {
		if got := Backoff(i + 1); got != w {
			t.Fatalf("attempt %d: got %v, want %v", i+1, got, w)
		}
	}
}
GO
git add -A
at "2026-09-24T10:15:00"; git commit -q -m "PAY-157: backoff helper for forwarding retries"
git checkout -q feature/PAY-157-webhook-verify

restore cmd/receiver/main.go internal/webhook/store.go internal/webhook/handler.go internal/webhook/handler_test.go
python3 - <<'PY'
h = open('internal/webhook/handler.go').read()
a = h.index('\t// Replay protection')
b = h.index('\tvar ev event')
open('internal/webhook/handler.go', 'w').write(h[:a] + h[b:])
t = open('internal/webhook/handler_test.go').read()
open('internal/webhook/handler_test.go', 'w').write(t[: t.index('\n\nfunc TestRejectsReplayedEvent')] + '\n')
PY
git add -A
at "2026-09-23T18:05:00"; git commit -q -m "PAY-157: answer a repeated event id once"

restore internal/webhook/handler.go internal/webhook/handler_test.go
git add -A
at "2026-09-25T19:40:00"; git commit -q -m "PAY-157: reject replayed events (done)"

# Half-done forwarding, stashed at the end of the session.
cat > internal/webhook/forward.go <<'GO'
package webhook

import (
	"bytes"
	"fmt"
	"net/http"
	"time"
)

// Forwarder posts accepted events to the orders service.
type Forwarder struct {
	URL    string
	Client *http.Client
}

// Forward sends body to the orders service, retrying a 5xx.
// TODO: backoff between attempts, and decide what to answer the provider
// when all attempts fail.
func (f *Forwarder) Forward(body []byte) error {
	var last error
	for attempt := 1; attempt <= 3; attempt++ {
		resp, err := f.Client.Post(f.URL, "application/json", bytes.NewReader(body))
		if err != nil {
			last = err
			continue
		}
		resp.Body.Close()
		if resp.StatusCode < 500 {
			return nil
		}
		last = fmt.Errorf("orders service answered %d", resp.StatusCode)
		time.Sleep(0)
	}
	return last
}
GO
python3 - <<'PY'
h = open('internal/webhook/handler.go').read()
h = h.replace('\tTolerance time.Duration\n}', '\tTolerance time.Duration\n\tForward   *Forwarder\n}')
open('internal/webhook/handler.go', 'w').write(h)
PY
at "2026-09-25T20:10:00"
git stash push -q -u -m "PAY-157 forward to orders with retry, half done"
rm -r "$final"
