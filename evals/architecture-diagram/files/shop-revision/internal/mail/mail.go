package mail

import (
	"encoding/json"
	"fmt"
	"net/smtp"
)

type Mailer struct{ addr string }

func New(addr string) *Mailer { return &Mailer{addr: addr} }

func (m *Mailer) OrderConfirmation(payload []byte) error {
	var o struct {
		ID    string `json:"id"`
		Total int64  `json:"total_paise"`
	}
	if err := json.Unmarshal(payload, &o); err != nil {
		return err
	}
	msg := fmt.Sprintf("Subject: Order %s confirmed\r\n\r\nTotal Rs %d.%02d\r\n", o.ID, o.Total/100, o.Total%100)
	return smtp.SendMail(m.addr, nil, "orders@shop.example", []string{"customer@shop.example"}, []byte(msg))
}
