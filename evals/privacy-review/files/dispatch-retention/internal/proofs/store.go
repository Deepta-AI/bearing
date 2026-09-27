// Package proofs stores the photo and signature a rider takes at
// handover in the dispatch-proofs bucket (deploy/storage-lifecycle.json).
package proofs

import (
	"context"
	"fmt"
)

// Bucket is the slice of the object storage client the proofs need.
type Bucket interface {
	Put(ctx context.Context, key string, body []byte, contentType string) error
}

// PhotoKey is where the handover photo for a delivery is stored.
func PhotoKey(deliveryID int64) string {
	return fmt.Sprintf("deliveries/%d/photo.jpg", deliveryID)
}

// SignatureKey is where the recipient's signature for a delivery is stored.
func SignatureKey(deliveryID int64) string {
	return fmt.Sprintf("deliveries/%d/signature.png", deliveryID)
}

// Save uploads both images and returns their keys for delivery_proofs.
func Save(ctx context.Context, b Bucket, deliveryID int64, photo, signature []byte) (string, string, error) {
	pk, sk := PhotoKey(deliveryID), SignatureKey(deliveryID)
	if err := b.Put(ctx, pk, photo, "image/jpeg"); err != nil {
		return "", "", err
	}
	if err := b.Put(ctx, sk, signature, "image/png"); err != nil {
		return "", "", err
	}
	return pk, sk, nil
}
