// Package ship encodes a metric map and exports it, retrying with backoff.
package ship

import (
	"time"

	"example.net/codec/msgpk"
	"example.net/telemetry/otlpish"
	"example.net/util/backoff"
)

// Shipper exports metric maps to one collector.
type Shipper struct {
	exp   *otlpish.Exporter
	tries int
}

// New returns a shipper for endpoint.
func New(endpoint string) *Shipper { return &Shipper{exp: otlpish.New(endpoint), tries: 4} }

// Send encodes m and exports it, retrying on error.
func (s *Shipper) Send(m map[string]float64) error {
	batch := msgpk.EncodeMap(m)
	var err error
	for i := 0; i < s.tries; i++ {
		if err = s.exp.Export(batch); err == nil {
			return nil
		}
		time.Sleep(backoff.Delay(i, 200*time.Millisecond, 5*time.Second))
	}
	return err
}
