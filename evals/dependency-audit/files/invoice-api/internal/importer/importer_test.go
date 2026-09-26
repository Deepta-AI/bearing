package importer

import (
	"net/http/httptest"
	"strings"
	"testing"

	"example.com/invoice-api/internal/billing"
)

func TestImport(t *testing.T) {
	s := billing.NewStore()
	body := `<batch><invoice><customer>c1</customer><net>10000</net></invoice>` +
		`<invoice><customer>c2</customer><net>1025</net></invoice></batch>`
	rec := httptest.NewRecorder()
	Handler(s).ServeHTTP(rec, httptest.NewRequest("POST", "/import", strings.NewReader(body)))
	if rec.Code != 200 {
		t.Fatalf("status %d: %s", rec.Code, rec.Body)
	}
	got := s.All()
	if len(got) != 2 || got[1].Total != 1210 {
		t.Fatalf("got %+v", got)
	}
}
