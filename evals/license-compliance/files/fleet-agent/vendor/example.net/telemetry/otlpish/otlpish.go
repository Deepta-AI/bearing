// Copyright 2021 The Otlpish Project Authors
// SPDX-License-Identifier: Apache-2.0

// Package otlpish posts metric batches to a collector over HTTP.
package otlpish

import (
	"bytes"
	"net/http"
	"time"
)

// Exporter sends encoded batches to one endpoint.
type Exporter struct {
	Endpoint string
	Client   *http.Client
}

// New returns an exporter with a bounded timeout.
func New(endpoint string) *Exporter {
	return &Exporter{Endpoint: endpoint, Client: &http.Client{Timeout: 10 * time.Second}}
}

// Export posts one batch.
func (e *Exporter) Export(batch []byte) error {
	resp, err := e.Client.Post(e.Endpoint, "application/x-msgpk", bytes.NewReader(batch))
	if err != nil {
		return err
	}
	return resp.Body.Close()
}
