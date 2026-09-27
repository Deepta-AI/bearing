// Package cache is a minimal Redis client (GET, SET EX, PING) over RESP, kept
// small so the service has no third-party dependency.
package cache

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"net"
	"strconv"
	"time"
)

var ErrMiss = errors.New("cache miss")

type Redis struct {
	addr string
}

func NewRedis(addr string) *Redis { return &Redis{addr: addr} }

func (r *Redis) do(ctx context.Context, args ...string) (string, bool, error) {
	d := net.Dialer{Timeout: 1 * time.Second}
	conn, err := d.DialContext(ctx, "tcp", r.addr)
	if err != nil {
		return "", false, err
	}
	defer conn.Close()
	if dl, ok := ctx.Deadline(); ok {
		conn.SetDeadline(dl)
	} else {
		conn.SetDeadline(time.Now().Add(2 * time.Second))
	}
	cmd := fmt.Sprintf("*%d\r\n", len(args))
	for _, a := range args {
		cmd += fmt.Sprintf("$%d\r\n%s\r\n", len(a), a)
	}
	if _, err := conn.Write([]byte(cmd)); err != nil {
		return "", false, err
	}
	br := bufio.NewReader(conn)
	line, err := br.ReadString('\n')
	if err != nil {
		return "", false, err
	}
	line = line[:len(line)-2]
	switch line[0] {
	case '+':
		return line[1:], true, nil
	case '-':
		return "", false, errors.New(line[1:])
	case '$':
		n, _ := strconv.Atoi(line[1:])
		if n < 0 {
			return "", false, nil
		}
		buf := make([]byte, n+2)
		if _, err := readFull(br, buf); err != nil {
			return "", false, err
		}
		return string(buf[:n]), true, nil
	}
	return "", false, fmt.Errorf("unexpected reply %q", line)
}

func readFull(br *bufio.Reader, buf []byte) (int, error) {
	n := 0
	for n < len(buf) {
		m, err := br.Read(buf[n:])
		n += m
		if err != nil {
			return n, err
		}
	}
	return n, nil
}

func (r *Redis) Get(ctx context.Context, key string) ([]byte, error) {
	v, ok, err := r.do(ctx, "GET", key)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrMiss
	}
	return []byte(v), nil
}

func (r *Redis) Set(ctx context.Context, key string, val []byte, ttl time.Duration) error {
	_, _, err := r.do(ctx, "SET", key, string(val), "EX", strconv.Itoa(int(ttl.Seconds())))
	return err
}

func (r *Redis) Ping(ctx context.Context) error {
	_, _, err := r.do(ctx, "PING")
	return err
}
