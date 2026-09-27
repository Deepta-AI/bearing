package orders

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"
)

// Notifier stands in for the email provider. Addresses at full.example
// behave like a full mailbox. Like the real client it gives up when ctx
// is cancelled.
type Notifier struct{}

func (Notifier) send(ctx context.Context, to, subject string) error {
	select {
	case <-ctx.Done():
		return fmt.Errorf("send to %s: %w", to, ctx.Err())
	case <-time.After(20 * time.Millisecond): // provider round trip
	}
	if strings.HasSuffix(to, "@full.example") {
		return fmt.Errorf("send to %s: mailbox full", to)
	}
	log.Printf("sent %q to %s", subject, to)
	return nil
}

func (n Notifier) OrderPlaced(ctx context.Context, o Order) error {
	return n.send(ctx, o.Email, "Order "+o.ID+" received")
}

func (n Notifier) OrderShipped(ctx context.Context, o Order) error {
	return n.send(ctx, o.Email, "Order "+o.ID+" shipped")
}
