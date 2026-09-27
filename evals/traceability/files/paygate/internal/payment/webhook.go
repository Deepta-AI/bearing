package payment

// WebhookStatus maps a gateway webhook status to our capture state.
func WebhookStatus(s string) string {
	switch s {
	case "captured", "settled":
		return "captured"
	case "failed":
		return "failed"
	}
	return "pending"
}
