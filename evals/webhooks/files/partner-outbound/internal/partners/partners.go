// Package partners holds the resellers who fulfil orders.
package partners

type Partner struct {
	ID         string
	Name       string
	WebhookURL string // empty: the partner still polls
	SecretEnv  string // name of the env var holding the shared secret
	Active     bool
}

type Store interface {
	Get(id string) (Partner, bool)
}

type Memory map[string]Partner

func (m Memory) Get(id string) (Partner, bool) {
	p, ok := m[id]
	return p, ok
}
