package sms

import "testing"

type fake struct{ text string }

func (f *fake) Send(_, text string) error { f.text = text; return nil }

func TestOrderPaid(t *testing.T) {
	f := &fake{}
	if err := OrderPaid(f, "+910000000000", "o1"); err != nil {
		t.Fatal(err)
	}
	if f.text != "Payment received for order o1." {
		t.Fatalf("got %q", f.text)
	}
}
