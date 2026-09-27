// Package notify sends order receipts in the background so checkout does
// not wait on the mail provider.
package notify

import (
	"math/rand/v2"
	"sync"
	"time"
)

// Sender delivers one receipt. The real one calls the mail provider.
type Sender interface {
	Send(orderID string) error
}

// Notifier queues receipts and sends them from one background goroutine.
type Notifier struct {
	sender Sender
	queue  chan string
	// MaxLatency is the provider's observed latency ceiling; each send takes
	// a random time up to it.
	MaxLatency time.Duration
}

func New(sender Sender) *Notifier {
	n := &Notifier{sender: sender, queue: make(chan string, 64), MaxLatency: 12 * time.Millisecond}
	go n.run()
	return n
}

// OrderPlaced queues a receipt and returns at once.
func (n *Notifier) OrderPlaced(orderID string) {
	n.queue <- orderID
}

func (n *Notifier) run() {
	for id := range n.queue {
		if n.MaxLatency > 0 {
			time.Sleep(rand.N(n.MaxLatency))
		}
		_ = n.sender.Send(id)
	}
}

// RecordingSender remembers what it sent; safe for concurrent use.
type RecordingSender struct {
	mu   sync.Mutex
	sent []string
}

func (r *RecordingSender) Send(orderID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.sent = append(r.sent, orderID)
	return nil
}

func (r *RecordingSender) Sent() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]string(nil), r.sent...)
}
