// Command api runs the filedrop HTTP server.
package main

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"

	"example.com/filedrop/internal/auth"
	"example.com/filedrop/internal/config"
	"example.com/filedrop/internal/files"
	"example.com/filedrop/internal/share"
)

type noUsers struct{}

func (noUsers) ByEmail(string) (auth.User, bool) { return auth.User{}, false }

func main() {
	cfg := config.Load()
	signer := auth.Signer{Key: cfg.SessionSecret}
	store := files.NewStore()
	links := share.NewLinks()

	mux := http.NewServeMux()
	mux.Handle("POST /login", auth.LoginHandler(noUsers{}, signer))
	files.Handler{Store: store, Preview: func(f files.File) ([]byte, error) {
		return nil, errors.New("renderer unavailable at /opt/filedrop/bin/thumbd: " + f.ID)
	}}.Register(mux, signer)

	mux.Handle("POST /files/{id}/share", signer.Require(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sess := auth.From(r.Context())
		f, ok := store.Get(r.PathValue("id"))
		if !ok || f.TenantID != sess.TenantID {
			http.NotFound(w, r)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"url": "/s/" + links.Create(f.ID, f.TenantID)})
	})))
	mux.Handle("GET /s/{token}", links.Serve(func(id string) ([]byte, string, bool) {
		f, ok := store.Get(id)
		return f.Data, f.Name, ok
	}))

	log.Printf("filedrop listening on %s", cfg.Addr)
	log.Fatal(http.ListenAndServe(cfg.Addr, mux))
}
