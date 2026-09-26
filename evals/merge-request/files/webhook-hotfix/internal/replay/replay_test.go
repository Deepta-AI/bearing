package replay

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"testing"
)

var secret = []byte("test-secret")

func stored(ts, body string) Delivery {
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(ts + "."))
	mac.Write([]byte(body))
	return Delivery{Timestamp: ts, Body: []byte(body), Signature: hex.EncodeToString(mac.Sum(nil))}
}

// Deliveries stored during an outage are replayed hours later.
func TestReplayStoredDeliveries(t *testing.T) {
	ds := []Delivery{
		stored("1788000000", `{"event":"order.paid","id":"o1"}`),
		stored("1788000060", `{"event":"order.paid","id":"o2"}`),
	}
	var got []string
	n, err := Replay(secret, ds, func(d Delivery) error {
		got = append(got, d.Timestamp)
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if n != 2 || len(got) != 2 {
		t.Fatalf("replayed %d, want 2", n)
	}
}
