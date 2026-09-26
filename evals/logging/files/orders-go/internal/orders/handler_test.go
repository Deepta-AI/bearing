package orders

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func post(h Handler, body string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	h.Create(rec, httptest.NewRequest("POST", "/orders", strings.NewReader(body)))
	return rec
}

func TestCreateAndBadQty(t *testing.T) {
	h := Handler{Svc: NewService(NewMemStore())}
	if rec := post(h, `{"email":"asha@example.com","phone":"+919800000000","sku":"A1","qty":2}`); rec.Code != http.StatusCreated {
		t.Fatalf("create: got %d", rec.Code)
	}
	if rec := post(h, `{"email":"asha@example.com","sku":"A1","qty":0}`); rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("bad qty: got %d", rec.Code)
	}
	if rec := post(h, `{"email":"chargeback@example.com","sku":"A1","qty":1}`); rec.Code != http.StatusForbidden {
		t.Fatalf("blocked: got %d", rec.Code)
	}
}

func TestListAndExport(t *testing.T) {
	h := Handler{Svc: NewService(NewMemStore())}
	post(h, `{"email":"asha@example.com","sku":"A1","qty":2}`)
	post(h, `{"email":"ravi@example.com","sku":"B2","qty":1}`)

	rec := httptest.NewRecorder()
	h.List(rec, httptest.NewRequest("GET", "/orders?email=asha@example.com", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"o-1"`) || strings.Contains(rec.Body.String(), `"o-2"`) {
		t.Fatalf("list: %d %s", rec.Code, rec.Body.String())
	}

	rec = httptest.NewRecorder()
	h.Export(rec, httptest.NewRequest("GET", "/orders/export", nil))
	if rec.Code != http.StatusOK || strings.Count(rec.Body.String(), "\n") != 2 {
		t.Fatalf("export: %d %q", rec.Code, rec.Body.String())
	}
}

func TestFulfilKeepsGoingAfterAFailedNotification(t *testing.T) {
	svc := NewService(NewMemStore())
	h := Handler{Svc: svc}
	post(h, `{"email":"full@full.example","sku":"A1","qty":1}`)
	post(h, `{"email":"asha@example.com","sku":"A1","qty":1}`)
	n, err := svc.FulfilPending(Notifier{})
	if n != 2 || err == nil {
		t.Fatalf("fulfil: n=%d err=%v", n, err)
	}
}

func TestAPIKey(t *testing.T) {
	ok := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(200) })
	h := RequireAPIKey("k1", ok)
	for _, c := range []struct {
		path, key string
		want      int
	}{{"/orders/o-1", "", 401}, {"/orders/o-1", "wrong", 401}, {"/orders/o-1", "k1", 200}, {"/healthz", "", 200}} {
		rec := httptest.NewRecorder()
		req := httptest.NewRequest("GET", c.path, nil)
		req.Header.Set("X-Api-Key", c.key)
		h.ServeHTTP(rec, req)
		if rec.Code != c.want {
			t.Fatalf("%s key=%q: got %d want %d", c.path, c.key, rec.Code, c.want)
		}
	}
}
