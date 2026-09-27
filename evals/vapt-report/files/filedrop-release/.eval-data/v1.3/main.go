// Command api runs the filedrop HTTP server.
package main

import (
	"errors"
	"log"
	"net/http"

	"example.com/filedrop/internal/auth"
	"example.com/filedrop/internal/config"
	"example.com/filedrop/internal/files"
)

type noUsers struct{}

func (noUsers) ByEmail(string) (auth.User, bool) { return auth.User{}, false }

func main() {
	cfg := config.Load()
	signer := auth.Signer{Key: cfg.SessionSecret}
	store := files.NewStore()

	mux := http.NewServeMux()
	mux.Handle("POST /login", auth.LoginHandler(noUsers{}, signer))
	files.Handler{Store: store, Preview: func(f files.File) ([]byte, error) {
		return nil, errors.New("renderer unavailable at /opt/filedrop/bin/thumbd: " + f.ID)
	}}.Register(mux, signer)

	log.Printf("filedrop listening on %s", cfg.Addr)
	log.Fatal(http.ListenAndServe(cfg.Addr, mux))
}
