package proofs

import (
	"context"
	"testing"
)

type memBucket map[string][]byte

func (m memBucket) Put(_ context.Context, key string, body []byte, _ string) error {
	m[key] = body
	return nil
}

func TestSaveStoresBothImages(t *testing.T) {
	b := memBucket{}
	pk, sk, err := Save(context.Background(), b, 42, []byte("jpg"), []byte("png"))
	if err != nil {
		t.Fatal(err)
	}
	if string(b[pk]) != "jpg" || string(b[sk]) != "png" {
		t.Fatalf("stored %v", b)
	}
}
