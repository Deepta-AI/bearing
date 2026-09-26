// Package jobs runs background work off the request path.
package jobs

import (
	"context"
	"log"
)

// Job is one unit of background work.
type Job func(ctx context.Context) error

// Queue runs jobs on a single worker goroutine.
type Queue struct{ ch chan Job }

func NewQueue(size int) *Queue { return &Queue{ch: make(chan Job, size)} }

// Enqueue hands a job to the worker without waiting for it to run.
func (q *Queue) Enqueue(j Job) { q.ch <- j }

// Run drains the queue until ctx is done.
func (q *Queue) Run(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case j := <-q.ch:
			if err := j(ctx); err != nil {
				log.Printf("job failed: %v", err)
			}
		}
	}
}
