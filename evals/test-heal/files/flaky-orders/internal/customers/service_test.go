package customers

import (
	"errors"
	"fmt"
	"strings"
	"testing"

	"example.com/orders/internal/store"
	"example.com/orders/internal/testutil"
)

// TC-0201: a new email registers and gets an id.
func TestRegisterCustomer(t *testing.T) {
	svc := &Service{Store: testutil.Store}
	c, err := svc.Register(testutil.AshaEmail, "Asha")
	if err != nil {
		t.Fatalf("Register: %v", err)
	}
	if c.ID == 0 || c.Email != testutil.AshaEmail {
		t.Fatalf("got %+v", c)
	}
}

// TC-0202: an import registers every new row, counts duplicates and adds
// exactly the new customers to the store.
func TestImportCustomers(t *testing.T) {
	svc := &Service{Store: testutil.Store}
	csv := testutil.RaviEmail + ",Ravi\n" + testutil.RaviEmail + ",Ravi again\n"
	res, err := svc.Import(strings.NewReader(csv))
	if err != nil {
		t.Fatalf("Import: %v", err)
	}
	if res.Imported != 1 || res.Duplicates != 1 {
		t.Fatalf("got %+v, want 1 imported and 1 duplicate", res)
	}
	if n := testutil.Store.Count(); n != 1 {
		t.Fatalf("store holds %d customers after the import, want 1", n)
	}
}

// TC-0206: a batch of new customers imports in full, with no duplicates.
func TestImportNewCustomersBatch(t *testing.T) {
	svc := &Service{Store: store.New()}
	var csv strings.Builder
	for i := 0; i < 3; i++ {
		fmt.Fprintf(&csv, "%s,Customer %d\n", testutil.RandomEmail(), i+1)
	}
	res, err := svc.Import(strings.NewReader(csv.String()))
	if err != nil {
		t.Fatalf("Import: %v", err)
	}
	if res.Imported != 3 || res.Duplicates != 0 {
		t.Fatalf("got %+v, want 3 imported and 0 duplicates", res)
	}
	if n := svc.Store.Count(); n != 3 {
		t.Fatalf("store holds %d customers, want 3", n)
	}
}

// TC-0205: the same email in a different case is a duplicate.
func TestRegisterDuplicateEmailCaseInsensitive(t *testing.T) {
	svc := &Service{Store: store.New()}
	if _, err := svc.Register("Meera@Example.com", "Meera"); err != nil {
		t.Fatalf("first Register: %v", err)
	}
	_, err := svc.Register("meera@example.com", "Meera")
	if !errors.Is(err, store.ErrDuplicateEmail) {
		t.Fatalf("got %v, want ErrDuplicateEmail", err)
	}
}

func TestRegisterRejectsInvalidEmail(t *testing.T) {
	svc := &Service{Store: store.New()}
	if _, err := svc.Register("not-an-email", "X"); err == nil {
		t.Fatal("want an error for an invalid email")
	}
}
