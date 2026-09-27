package reports

import "fmt"

// Sink stores one archived object, for example in the warehouse bucket.
type Sink interface {
	Put(key string, body []byte) error
}

// Archive writes every report in the store as CSV to sink, one object per
// report under archive/<account>/<id>.csv. The data warehouse loads these
// files nightly.
func Archive(s *Store, sink Sink) (int, error) {
	n := 0
	for _, r := range s.All() {
		body, err := BuildCSV(r)
		if err != nil {
			return n, fmt.Errorf("archive %s: %w", r.ID, err)
		}
		if err := sink.Put("archive/"+r.AccountID+"/"+r.ID+".csv", body); err != nil {
			return n, fmt.Errorf("archive %s: %w", r.ID, err)
		}
		n++
	}
	return n, nil
}
