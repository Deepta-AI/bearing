// Package cache is a minimal Redis client (RESP over TCP) for the order
// read cache. Only the commands orders-api uses are implemented.
package cache

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"
	"time"
)

var ErrMiss = errors.New("cache: miss")

type Client struct {
	addr    string
	timeout time.Duration
}

func New(addr string, timeout time.Duration) *Client {
	return &Client{addr: addr, timeout: timeout}
}

func (c *Client) Get(ctx context.Context, key string) (string, error) {
	reply, err := c.do(ctx, "GET", key)
	if err != nil {
		return "", err
	}
	if reply == nil {
		return "", ErrMiss
	}
	return *reply, nil
}

func (c *Client) Set(ctx context.Context, key, value string, ttl time.Duration) error {
	_, err := c.do(ctx, "SET", key, value, "PX", strconv.FormatInt(ttl.Milliseconds(), 10))
	return err
}

// do sends one command on a fresh connection and reads a simple, error or
// bulk string reply. A nil reply is a RESP null bulk string.
func (c *Client) do(ctx context.Context, args ...string) (*string, error) {
	d := net.Dialer{Timeout: c.timeout}
	conn, err := d.DialContext(ctx, "tcp", c.addr)
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	deadline := time.Now().Add(c.timeout)
	if dl, ok := ctx.Deadline(); ok && dl.Before(deadline) {
		deadline = dl
	}
	_ = conn.SetDeadline(deadline)

	var b strings.Builder
	fmt.Fprintf(&b, "*%d\r\n", len(args))
	for _, a := range args {
		fmt.Fprintf(&b, "$%d\r\n%s\r\n", len(a), a)
	}
	if _, err := conn.Write([]byte(b.String())); err != nil {
		return nil, err
	}
	r := bufio.NewReader(conn)
	line, err := r.ReadString('\n')
	if err != nil {
		return nil, err
	}
	line = strings.TrimRight(line, "\r\n")
	switch {
	case strings.HasPrefix(line, "+"):
		s := line[1:]
		return &s, nil
	case strings.HasPrefix(line, "-"):
		return nil, errors.New("redis: " + line[1:])
	case line == "$-1":
		return nil, nil
	case strings.HasPrefix(line, "$"):
		n, err := strconv.Atoi(line[1:])
		if err != nil {
			return nil, err
		}
		buf := make([]byte, n+2)
		if _, err := ioReadFull(r, buf); err != nil {
			return nil, err
		}
		s := string(buf[:n])
		return &s, nil
	}
	return nil, fmt.Errorf("redis: unexpected reply %q", line)
}

func ioReadFull(r *bufio.Reader, buf []byte) (int, error) {
	n := 0
	for n < len(buf) {
		m, err := r.Read(buf[n:])
		n += m
		if err != nil {
			return n, err
		}
	}
	return n, nil
}
