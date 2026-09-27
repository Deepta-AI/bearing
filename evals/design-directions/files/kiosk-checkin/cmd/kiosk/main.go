package main

import (
	"html/template"
	"log"
	"net/http"

	"example.com/queuewell/internal/kiosk"
)

func main() {
	s := &kiosk.Server{
		T: template.Must(template.ParseGlob("templates/*.html")),
		Appts: map[string]kiosk.Appointment{
			"K7Q2MX": {Code: "K7Q2MX", BirthYear2: "58", First: "Asha", Last: "Kulkarni", WaitingArea: "Waiting area B", Token: "B-14"},
		},
	}
	log.Println("kiosk on :8080")
	log.Fatal(http.ListenAndServe(":8080", s.Routes()))
}
