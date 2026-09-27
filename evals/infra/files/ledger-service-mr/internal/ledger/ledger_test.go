package ledger

import "testing"

func TestValidate(t *testing.T) {
	cases := []struct {
		name    string
		entries []Entry
		ok      bool
	}{
		{"balanced", []Entry{{"cash", 500}, {"revenue", -500}}, true},
		{"unbalanced", []Entry{{"cash", 500}, {"revenue", -400}}, false},
		{"single", []Entry{{"cash", 0}}, false},
	}
	for _, c := range cases {
		if err := Validate(c.entries); (err == nil) != c.ok {
			t.Errorf("%s: got %v", c.name, err)
		}
	}
}
