//go:build release

package main

// The release image links the Postgres driver; unit tests use fakes and do not need it.
import _ "github.com/lib/pq"
