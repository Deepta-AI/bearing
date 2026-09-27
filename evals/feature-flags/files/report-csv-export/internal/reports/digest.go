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
	// BaseURL is the public address of the service, for links in the email.
	BaseURL string
}

// SendWeekly sends one digest to accountID at address.
func (d *Digest) SendWeekly(accountID, address string) error {
	reports := d.Store.ByAccount(accountID)
	if len(reports) == 0 {
		return nil
	}
	var b strings.Builder
	b.WriteString("Your reports this week:\n")
	msg := Email{To: address, Subject: "Your weekly reports"}
	for _, r := range reports {
		fmt.Fprintf(&b, "- %s (%d rows)\n", r.Title, len(r.Rows))
		fmt.Fprintf(&b, "  download: %s/reports/%s/export.csv\n", d.BaseURL, r.ID)
		body, err := BuildCSV(r)
		if err != nil {
			return fmt.Errorf("digest csv %s: %w", r.ID, err)
		}
		msg.Attachments = append(msg.Attachments, Attachment{Name: r.ID + ".csv", Body: body})
	}
	msg.Body = b.String()
	return d.Sender.Send(msg)
}
