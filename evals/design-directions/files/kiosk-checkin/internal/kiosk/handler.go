package kiosk

import (
	"html/template"
	"net/http"
	"strings"
)

type Appointment struct {
	Code        string
	BirthYear2  string
	First, Last string
	WaitingArea string
	Token       string
}

type Server struct {
	T     *template.Template
	Appts map[string]Appointment
}

type confirmedView struct {
	Name, WaitingArea, Token string
}

func (s *Server) Routes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		s.render(w, "start.html", nil)
	})
	mux.HandleFunc("POST /checkin", s.checkin)
	mux.Handle("GET /static/", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))
	return mux
}

func (s *Server) checkin(w http.ResponseWriter, r *http.Request) {
	code := strings.ToUpper(strings.TrimSpace(r.FormValue("code")))
	year := strings.TrimSpace(r.FormValue("year"))
	a, ok := s.Appts[code]
	if !ok || a.BirthYear2 != year {
		w.WriteHeader(http.StatusNotFound)
		s.render(w, "notfound.html", nil)
		return
	}
	s.render(w, "confirmed.html", confirmedView{
		Name:        DisplayName(a.First, a.Last),
		WaitingArea: a.WaitingArea,
		Token:       a.Token,
	})
}

func (s *Server) render(w http.ResponseWriter, name string, data any) {
	if err := s.T.ExecuteTemplate(w, name, data); err != nil {
		http.Error(w, "template error", http.StatusInternalServerError)
	}
}
