package kiosk

import (
	"html/template"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func TestDisplayName(t *testing.T) {
	cases := []struct{ first, last, want string }{
		{"Asha", "Kulkarni", "Asha K."},
		{"Ravi", "", "Ravi"},
		{" Meena ", " Iyer", "Meena I."},
	}
	for _, c := range cases {
		if got := DisplayName(c.first, c.last); got != c.want {
			t.Errorf("DisplayName(%q, %q) = %q, want %q", c.first, c.last, got, c.want)
		}
	}
}

func TestCheckinShowsOnlyDisplayName(t *testing.T) {
	tpl := template.Must(template.ParseGlob("../../templates/*.html"))
	s := &Server{T: tpl, Appts: map[string]Appointment{
		"K7Q2MX": {Code: "K7Q2MX", BirthYear2: "58", First: "Asha", Last: "Kulkarni", WaitingArea: "Waiting area B", Token: "B-14"},
	}}
	form := url.Values{"code": {"k7q2mx"}, "year": {"58"}}
	req := httptest.NewRequest(http.MethodPost, "/checkin", strings.NewReader(form.Encode()))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	rec := httptest.NewRecorder()
	s.Routes().ServeHTTP(rec, req)
	body := rec.Body.String()
	if rec.Code != http.StatusOK || !strings.Contains(body, "Asha K.") || strings.Contains(body, "Kulkarni") {
		t.Fatalf("status %d, body %s", rec.Code, body)
	}
}

func TestCheckinUnknownCode(t *testing.T) {
	tpl := template.Must(template.ParseGlob("../../templates/*.html"))
	s := &Server{T: tpl, Appts: map[string]Appointment{}}
	req := httptest.NewRequest(http.MethodPost, "/checkin", strings.NewReader("code=AAAAAA&year=70"))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	rec := httptest.NewRecorder()
	s.Routes().ServeHTTP(rec, req)
	if rec.Code != http.StatusNotFound || !strings.Contains(rec.Body.String(), "couldn") {
		t.Fatalf("status %d", rec.Code)
	}
}
