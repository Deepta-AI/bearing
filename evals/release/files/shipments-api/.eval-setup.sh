#!/usr/bin/env bash
# Builds this fixture's history in place. The files on disk are the final
# working tree of main; the earlier versions are written here.
#   v1.4.0 (annotated) on main, 2026-08-18; the Helm chart's appVersion
#     also carries the version (the image tag defaults to it), which the
#     README's "the version lives in" line does not mention
#   hotfix/1.4.1 branched from v1.4.0: caps limit at 100, tagged v1.4.1,
#     never merged back into main
#   main after v1.4.0: status filter (feat), carrier fields nested
#     (refactor whose BREAKING CHANGE is only in the footer), CSV export
#     (feat) and its revert, 404 for unknown ids (fix), a logging tidy-up
#     with no Conventional prefix, a docs commit
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
at() { export GIT_AUTHOR_DATE="$1 +0530" GIT_COMMITTER_DATE="$1 +0530"; }
who() { export GIT_AUTHOR_NAME="$1" GIT_AUTHOR_EMAIL="$2" GIT_COMMITTER_NAME="$1" GIT_COMMITTER_EMAIL="$2"; }
final=$(mktemp -d)
cp -a . "$final/"
restore() { for p in "$@"; do cp "$final/$p" "$p"; done; }

# ---- state at v1.4.0 ----------------------------------------------------
cat > internal/store/memory.go <<'EOF'
// Package store holds shipments. The in-memory store backs tests and local
// runs; production uses the Postgres store in the platform repository.
package store

import "sync"

type Shipment struct {
	ID          string `json:"id"`
	Status      string `json:"status"`
	CarrierCode string `json:"carrier_code"`
	CarrierName string `json:"carrier_name"`
}

type Memory struct {
	mu   sync.Mutex
	rows []Shipment
}

func NewMemory(rows ...Shipment) *Memory { return &Memory{rows: rows} }

// List returns up to limit shipments.
func (m *Memory) List(limit int) []Shipment {
	m.mu.Lock()
	defer m.mu.Unlock()
	if limit > len(m.rows) {
		limit = len(m.rows)
	}
	return append([]Shipment{}, m.rows[:limit]...)
}

func (m *Memory) Get(id string) (Shipment, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, s := range m.rows {
		if s.ID == id {
			return s, true
		}
	}
	return Shipment{}, false
}
EOF
cat > internal/api/handler.go <<'EOF'
// Package api serves the shipments HTTP API.
package api

import (
	"encoding/json"
	"net/http"
	"strconv"

	"example.com/shipments-api/internal/store"
	"example.com/shipments-api/internal/version"
)

type Store interface {
	List(limit int) []store.Shipment
	Get(id string) (store.Shipment, bool)
}

const defaultLimit = 50

func NewHandler(s Store) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /v1/shipments", func(w http.ResponseWriter, r *http.Request) {
		limit := defaultLimit
		if v := r.URL.Query().Get("limit"); v != "" {
			n, err := strconv.Atoi(v)
			if err != nil || n < 1 {
				http.Error(w, "limit must be a positive integer", http.StatusBadRequest)
				return
			}
			limit = n
		}
		writeJSON(w, map[string]any{"shipments": s.List(limit)})
	})
	mux.HandleFunc("GET /v1/shipments/{id}", func(w http.ResponseWriter, r *http.Request) {
		sh, ok := s.Get(r.PathValue("id"))
		if !ok {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		writeJSON(w, sh)
	})
	mux.HandleFunc("GET /version", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]string{"version": version.Version})
	})
	return mux
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}
EOF
cat > internal/api/handler_test.go <<'EOF'
package api

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"example.com/shipments-api/internal/store"
)

func fixture() http.Handler {
	return NewHandler(store.NewMemory(
		store.Shipment{ID: "s1", Status: "in_transit", CarrierCode: "BLD", CarrierName: "Bluedart"},
		store.Shipment{ID: "s2", Status: "delivered", CarrierCode: "DLV", CarrierName: "Delhivery"},
	))
}

func get(t *testing.T, h http.Handler, path string) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec
}

func TestListOK(t *testing.T) {
	if rec := get(t, fixture(), "/v1/shipments?limit=1"); rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
}

func TestBadLimitIs400(t *testing.T) {
	if rec := get(t, fixture(), "/v1/shipments?limit=zero"); rec.Code != http.StatusBadRequest {
		t.Fatalf("status %d, want 400", rec.Code)
	}
}
EOF
cat > cmd/server/main.go <<'EOF'
package main

import (
	"log"
	"net/http"
	"os"

	"example.com/shipments-api/internal/api"
	"example.com/shipments-api/internal/store"
	"example.com/shipments-api/internal/version"
)

func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	log.Printf("shipments-api %s listening on %s", version.Version, addr)
	h := api.NewHandler(store.NewMemory())
	log.Fatal(http.ListenAndServe(addr, h))
}
EOF
cat > api/openapi.yaml <<'EOF'
openapi: 3.0.3
info:
  title: shipments-api
  version: "1"
paths:
  /v1/shipments:
    get:
      parameters:
        - {name: limit, in: query, schema: {type: integer, minimum: 1, default: 50}}
      responses:
        "200":
          description: A page of shipments
          content:
            application/json:
              schema:
                type: object
                properties:
                  shipments: {type: array, items: {$ref: "#/components/schemas/Shipment"}}
  /v1/shipments/{id}:
    get:
      parameters:
        - {name: id, in: path, required: true, schema: {type: string}}
      responses:
        "200":
          description: One shipment
          content:
            application/json:
              schema: {$ref: "#/components/schemas/Shipment"}
components:
  schemas:
    Shipment:
      type: object
      properties:
        id: {type: string}
        status: {type: string}
        carrier_code: {type: string}
        carrier_name: {type: string}
EOF
sed -i -e 's/^- `GET \/v1\/shipments?status=&limit=` lists shipments; `status` is one of$/- `GET \/v1\/shipments?limit=` lists shipments; `limit` defaults to 50./' \
  -e '/^  `created`, `in_transit`, `delivered`; `limit` defaults to 50.$/d' \
  -e 's/^- `GET \/v1\/shipments\/{id}` returns one shipment, 404 when unknown.$/- `GET \/v1\/shipments\/{id}` returns one shipment./' README.md

git init -q -b main
at "2026-08-18 12:00:00"
git add -A
git commit -q -m "chore(release): v1.4.0"
git tag -a v1.4.0 -m "v1.4.0"

# ---- hotfix/1.4.1, never merged back ------------------------------------
who "Dev Two" "dev.two@example.com"
git checkout -q -b hotfix/1.4.1 v1.4.0
at "2026-08-29 22:40:00"
python3 - <<'PY'
p = "internal/api/handler.go"
s = open(p).read()
s = s.replace("const defaultLimit = 50\n", "const defaultLimit = 50\n\n// maxLimit caps a page: an unbounded limit let one partner request load\n// every shipment into memory and restart the pod (incident 2026-08-29).\nconst maxLimit = 100\n")
s = s.replace("\t\t\tlimit = n\n", "\t\t\tlimit = min(n, maxLimit)\n")
open(p, "w").write(s)
p = "internal/api/handler_test.go"
s = open(p).read()
s += '''
func TestLimitIsCappedAt100(t *testing.T) {
	var rows []store.Shipment
	for i := 0; i < 150; i++ {
		rows = append(rows, store.Shipment{ID: "x"})
	}
	h := NewHandler(store.NewMemory(rows...))
	rec := get(t, h, "/v1/shipments?limit=100000")
	if n := strings.Count(rec.Body.String(), `"id"`); n != 100 {
		t.Fatalf("got %d shipments, want 100", n)
	}
}
'''
s = s.replace('import (\n\t"net/http"', 'import (\n\t"net/http"\n\t"strings"')
open(p, "w").write(s)
p = "CHANGELOG.md"
s = open(p).read()
s = s.replace("## [1.4.0]", "## [1.4.1] - 2026-08-29\n\n### Fixed\n- Cap `limit` on `GET /v1/shipments` at 100; an unbounded page could\n  exhaust the pod's memory.\n\n## [1.4.0]", 1)
open(p, "w").write(s)
PY
echo 1.4.1 > VERSION
sed -i 's/"1.4.0"/"1.4.1"/' internal/version/version.go
sed -i 's/^appVersion: "1.4.0"$/appVersion: "1.4.1"/' deploy/chart/Chart.yaml
git add -A
git commit -q -m "fix(api): cap limit at 100 to stop out-of-memory restarts"
at "2026-08-29 23:05:00"
git tag -a v1.4.1 -m "v1.4.1"
git checkout -q main
who "Dev One" "dev.one@example.com"

# ---- main after v1.4.0 --------------------------------------------------
# feat: status filter (store List gains status; flat carrier fields still)
python3 - <<'PY'
p = "internal/store/memory.go"
s = open(p).read()
s = s.replace('''// List returns up to limit shipments.
func (m *Memory) List(limit int) []Shipment {
	m.mu.Lock()
	defer m.mu.Unlock()
	if limit > len(m.rows) {
		limit = len(m.rows)
	}
	return append([]Shipment{}, m.rows[:limit]...)
}''', '''// List returns up to limit shipments, filtered by status when status is set.
func (m *Memory) List(status string, limit int) []Shipment {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := []Shipment{}
	for _, s := range m.rows {
		if status != "" && s.Status != status {
			continue
		}
		if len(out) == limit {
			break
		}
		out = append(out, s)
	}
	return out
}''')
open(p, "w").write(s)
p = "internal/api/handler.go"
s = open(p).read()
s = s.replace("List(limit int) []store.Shipment", "List(status string, limit int) []store.Shipment")
s = s.replace("s.List(limit)", 's.List(r.URL.Query().Get("status"), limit)')
open(p, "w").write(s)
PY
at "2026-08-25 15:10:00"
git add -A
git commit -q -m "feat(api): filter shipments by status"

# refactor with the breaking change only in the footer
restore internal/store/memory.go api/openapi.yaml
cp "$final/internal/api/handler_test.go" internal/api/handler_test.go
# at this point unknown ids still return 500: drop the 404 test for now
python3 - <<'PY'
p = "internal/api/handler_test.go"
s = open(p).read()
i = s.index("func TestUnknownShipmentIs404")
j = s.index("func TestBadLimitIs400")
open(p, "w").write(s[:i] + s[j:])
PY
sed -i '/404/d' api/openapi.yaml
at "2026-09-02 11:30:00"
git add -A
git commit -q -F - <<'MSG'
refactor(api): nest carrier fields under carrier

Group the carrier's code and name in one object so the dashboard can
render the carrier block from a single field.

BREAKING CHANGE: shipments no longer carry the flat carrier_code and
carrier_name fields; read carrier.code and carrier.name instead.
MSG

# feat: CSV export, then its revert
python3 - <<'PY'
p = "internal/api/handler.go"
s = open(p).read()
s = s.replace('\tmux.HandleFunc("GET /version"', '''\tmux.HandleFunc("GET /v1/shipments.csv", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/csv")
		cw := csv.NewWriter(w)
		_ = cw.Write([]string{"id", "status", "carrier_code"})
		for _, sh := range s.List(r.URL.Query().Get("status"), 1<<30) {
			_ = cw.Write([]string{sh.ID, sh.Status, sh.Carrier.Code})
		}
		cw.Flush()
	})
\tmux.HandleFunc("GET /version"''')
s = s.replace('import (\n\t"encoding/json"', 'import (\n\t"encoding/csv"\n\t"encoding/json"')
open(p, "w").write(s)
PY
at "2026-09-08 17:45:00"
git add -A
git commit -q -m "feat(export): CSV export of shipments"
csv_sha=$(git rev-parse HEAD)
who "Dev Two" "dev.two@example.com"
at "2026-09-10 10:05:00"
git revert --no-commit "$csv_sha"
git commit -q -F - <<MSG
Revert "feat(export): CSV export of shipments"

This reverts commit $csv_sha.

The export reads every shipment in one request and timed out for the
largest merchants. It comes back with pagination later.
MSG
who "Dev One" "dev.one@example.com"

# fix: 404 for unknown ids
restore internal/api/handler.go internal/api/handler_test.go api/openapi.yaml
at "2026-09-14 13:20:00"
git add -A
git commit -q -m "fix(api): return 404 instead of 500 for an unknown shipment id"

# no Conventional prefix
restore cmd/server/main.go
at "2026-09-16 09:50:00"
git add -A
git commit -q -m "tidy up request logging"

# docs
restore README.md
at "2026-09-18 16:00:00"
git add -A
git commit -q -m "docs: document the status filter and 404"

# anything left over must equal the final tree
cp -a "$final/." .
rm -f .eval-setup.sh .eval-branch
if [ -n "$(git status --porcelain)" ]; then
  echo "setup: final tree differs from the last commit" >&2
  git status --porcelain >&2
  exit 1
fi
rm -r "$final"
