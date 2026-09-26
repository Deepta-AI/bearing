package payments

import (
	"bytes"
	"io"
	"net/http"
)

func readAll(req *http.Request) ([]byte, error) {
	defer req.Body.Close()
	return io.ReadAll(req.Body)
}

func nopCloser(b []byte) io.ReadCloser { return io.NopCloser(bytes.NewReader(b)) }
