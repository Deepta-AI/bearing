package orders

import (
	"fmt"
	"log"
	"strings"
)

// Notifier stands in for the email provider. Addresses at full.example
// behave like a full mailbox.
type Notifier struct{}

func (Notifier) send(to, subject string) error {
	if strings.HasSuffix(to, "@full.example") {
		return fmt.Errorf("send to %s: mailbox full", to)
	}
	log.Printf("sent %q to %s", subject, to)
	return nil
}

func (n Notifier) OrderPlaced(o Order) error  { return n.send(o.Email, "Order "+o.ID+" received") }
func (n Notifier) OrderShipped(o Order) error { return n.send(o.Email, "Order "+o.ID+" shipped") }
