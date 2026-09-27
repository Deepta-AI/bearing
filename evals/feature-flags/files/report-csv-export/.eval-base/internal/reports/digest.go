package reports

import (
	"fmt"
	"strings"
)

// Attachment is a file attached to an email.
type Attachment struct {
	Name string
	Body []byte
}

// Email is one outgoing message.
type Email struct {
	To          string
	Subject     string
	Body        string
	Attachments []Attachment
}

// Sender delivers email.
type Sender interface {
	Send(Email) error
}

// Digest builds and sends the weekly digest.
type Digest struct {
	Store  *Store
	Sender Sender
}

// SendWeekly sends one digest to accountID at address.
func (d *Digest) SendWeekly(accountID, address string) error {
	reports := d.Store.ByAccount(accountID)
	if len(reports) == 0 {
		return nil
	}
	var b strings.Builder
	b.WriteString("Your reports this week:\n")
	for _, r := range reports {
		fmt.Fprintf(&b, "- %s (%d rows)\n", r.Title, len(r.Rows))
	}
	return d.Sender.Send(Email{To: address, Subject: "Your weekly reports", Body: b.String()})
}
