package httpapi

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"example.com/clinic-api/internal/store"
)

func login(t *testing.T, srv *httptest.Server, email string) *http.Cookie {
	t.Helper()
	res, err := http.Post(srv.URL+"/login", "application/json", strings.NewReader(`{"email":"`+email+`","password":"pw"}`))
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	for _, c := range res.Cookies() {
		if c.Name == "sid" {
			return c
		}
	}
	t.Fatalf("login %s: no sid cookie (status %d)", email, res.StatusCode)
	return nil
}

func TestDoctorOpensAppointment(t *testing.T) {
	srv := httptest.NewServer(Routes(store.Seeded()))
	defer srv.Close()
	sid := login(t, srv, "doctor@anand.test")

	req, _ := http.NewRequest("GET", srv.URL+"/appointments/a-1", nil)
	req.AddCookie(sid)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		t.Fatalf("status %d, want 200", res.StatusCode)
	}
}

func TestAnonymousIsRejected(t *testing.T) {
	srv := httptest.NewServer(Routes(store.Seeded()))
	defer srv.Close()
	res, err := http.Get(srv.URL + "/appointments/a-1")
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status %d, want 401", res.StatusCode)
	}
}
