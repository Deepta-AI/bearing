package orders

import (
	"context"
	"errors"
	"testing"

	"example.com/orders-api/internal/pricing"
)

type downPricer struct{}

func (downPricer) Quote(context.Context, string) (pricing.Quote, error) {
	return pricing.Quote{}, errors.New("connection refused")
}

type fixedPricer struct{ cents int64 }

func (p fixedPricer) Quote(_ context.Context, sku string) (pricing.Quote, error) {
	return pricing.Quote{SKU: sku, PriceCents: p.cents}, nil
}

func TestPriceFallsBackToListPriceWhenPricingIsDown(t *testing.T) {
	s := &Service{prices: downPricer{}}
	got := s.Price(context.Background(), []Line{{SKU: "A1", Qty: 2, ListPriceCents: 450}})
	if got[0].PriceCents != 450 {
		t.Fatalf("price = %d, want list price 450", got[0].PriceCents)
	}
}

func TestPriceUsesQuote(t *testing.T) {
	s := &Service{prices: fixedPricer{cents: 399}}
	got := s.Price(context.Background(), []Line{{SKU: "A1", Qty: 2, ListPriceCents: 450}})
	if Total(got) != 798 {
		t.Fatalf("total = %d, want 798", Total(got))
	}
}

func TestItoa(t *testing.T) {
	for n, want := range map[int64]string{0: "0", 7: "7", 1234: "1234", -12: "-12"} {
		if got := itoa(n); got != want {
			t.Errorf("itoa(%d) = %q, want %q", n, got, want)
		}
	}
}
