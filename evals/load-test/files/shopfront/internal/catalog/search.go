package catalog

import (
	"encoding/json"
	"strings"
	"sync"
)

const pageSize = 20

type Result struct {
	Query    string    `json:"query"`
	Page     int       `json:"page"`
	Products []Product `json:"products"`
}

type Catalog struct {
	products []Product

	mu    sync.Mutex
	cache map[string][]byte // encoded results by raw query and page, so a repeat search skips the scan and the encode
}

func New(p []Product) *Catalog {
	return &Catalog{products: p, cache: map[string][]byte{}}
}

// Search returns one page of products whose name contains every word of q,
// matched case-insensitively.
func (c *Catalog) Search(q string, page int) Result {
	var r Result
	json.Unmarshal(c.SearchJSON(q, page), &r)
	return r
}

// SearchJSON returns the JSON encoding of Search(q, page), as the API sends it.
func (c *Catalog) SearchJSON(q string, page int) []byte {
	if page < 1 {
		page = 1
	}
	key := q + "|" + itoa(page)
	c.mu.Lock()
	if b, ok := c.cache[key]; ok {
		c.mu.Unlock()
		return b
	}
	c.mu.Unlock()

	words := strings.Fields(strings.ToLower(q))
	var hits []Product
	for _, p := range c.products {
		name := strings.ToLower(p.Name)
		ok := true
		for _, w := range words {
			if !strings.Contains(name, w) {
				ok = false
				break
			}
		}
		if ok {
			hits = append(hits, p)
		}
	}
	start := (page - 1) * pageSize
	if start > len(hits) {
		start = len(hits)
	}
	end := min(start+pageSize, len(hits))
	r := Result{Query: q, Page: page, Products: hits[start:end]}
	if r.Products == nil {
		r.Products = []Product{}
	}
	b, _ := json.Marshal(r)
	b = append(b, '\n')

	c.mu.Lock()
	c.cache[key] = b
	c.mu.Unlock()
	return b
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b []byte
	for n > 0 {
		b = append([]byte{byte('0' + n%10)}, b...)
		n /= 10
	}
	return string(b)
}
