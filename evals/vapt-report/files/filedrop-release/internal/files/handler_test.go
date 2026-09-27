package files

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"example.com/filedrop/internal/auth"
)

func TestListShowsOnlyOwnTenant(t *testing.T) {
	st := NewStore()
	st.Put(File{TenantID: "t1", Name: "a.pdf"})
	st.Put(File{TenantID: "t2", Name: "b.pdf"})
	h := Handler{Store: st}
	r := httptest.NewRequest(http.MethodGet, "/files", nil)
	r = r.WithContext(auth.WithSession(r.Context(), auth.Session{UserID: "u1", TenantID: "t1"}))
	w := httptest.NewRecorder()
	h.list(w, r)
	var got []struct{ ID, Name string }
	json.NewDecoder(w.Body).Decode(&got)
	if len(got) != 1 || got[0].Name != "a.pdf" {
		t.Fatalf("list = %+v, want only a.pdf", got)
	}
}
