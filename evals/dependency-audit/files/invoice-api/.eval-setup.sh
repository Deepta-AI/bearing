#!/usr/bin/env bash
# Builds this fixture in place: writes the offline module mirror
# (third_party/goproxy, GOPROXY file format) for the internal modules and
# commits the tree on main. go.sum is in .gitignore, so it stays on disk
# untracked, as in the real repository. Run from the fixture copy; it
# removes itself first.
set -euo pipefail
rm -f .eval-setup.sh .eval-branch
python3 - <<'PY'
import json, os, zipfile

ROOT = "third_party/goproxy"

JWT_COMMON = '''
import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"
	"time"
)

// Claims are a token's JSON claims.
type Claims map[string]any

// ErrInvalid is returned for any token that fails to parse or verify.
var ErrInvalid = errors.New("jwtkit: invalid token")

var enc = base64.RawURLEncoding

func mac(msg string, key []byte) string {
	m := hmac.New(sha256.New, key)
	m.Write([]byte(msg))
	return enc.EncodeToString(m.Sum(nil))
}

// Sign returns an HS256 token for the claims.
func Sign(c Claims, key []byte) (string, error) {
	h, _ := json.Marshal(map[string]string{"alg": "HS256", "typ": "JWT"})
	b, err := json.Marshal(c)
	if err != nil {
		return "", err
	}
	msg := enc.EncodeToString(h) + "." + enc.EncodeToString(b)
	return msg + "." + mac(msg, key), nil
}

func split(token string) (alg string, claims Claims, msg, sig string, err error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return "", nil, "", "", ErrInvalid
	}
	hb, err1 := enc.DecodeString(parts[0])
	cb, err2 := enc.DecodeString(parts[1])
	if err1 != nil || err2 != nil {
		return "", nil, "", "", ErrInvalid
	}
	var h map[string]string
	if json.Unmarshal(hb, &h) != nil || json.Unmarshal(cb, &claims) != nil {
		return "", nil, "", "", ErrInvalid
	}
	return h["alg"], claims, parts[0] + "." + parts[1], parts[2], nil
}

func expired(c Claims, leeway time.Duration) bool {
	exp, ok := c["exp"].(float64)
	return ok && time.Now().Add(-leeway).Unix() > int64(exp)
}
'''

def jwtkit(ver):
    field = "ClockSkew" if ver == "v1.5.0" else "Leeway"
    none_check = (
        '\tif alg == "none" {\n\t\treturn claims, nil\n\t}\n'
        if ver == "v1.4.0" else
        '\tif alg != "HS256" {\n\t\treturn nil, ErrInvalid\n\t}\n'
    )
    src = "// Package jwtkit signs and parses HS256 tokens.\npackage jwtkit\n" + JWT_COMMON + f'''
// ParseOptions tune Parse.
type ParseOptions struct {{
	// {field} is the clock skew allowed when checking exp.
	{field} time.Duration
}}

// Parse verifies the token and returns its claims.
func Parse(token string, key []byte, opts ParseOptions) (Claims, error) {{
	alg, claims, msg, sig, err := split(token)
	if err != nil {{
		return nil, err
	}}
{none_check}	if !hmac.Equal([]byte(sig), []byte(mac(msg, key))) {{
		return nil, ErrInvalid
	}}
	if expired(claims, opts.{field}) {{
		return nil, ErrInvalid
	}}
	return claims, nil
}}
'''
    return {"jwtkit.go": src}

def money(ver):
    even = ver >= "v1.7.0"
    rule = "half-even (banker's)" if even else "half-up"
    tie = ("\tif 2*rem == 10000 && q%2 == 0 {\n\t\treturn q\n\t}\n" if even else "")
    src = f'''// Package money does integer arithmetic on minor currency units.
package money

// Percent returns amount * basisPoints / 10000, rounded {rule} to a whole
// minor unit. amount must not be negative.
func Percent(amount, basisPoints int64) int64 {{
	q, rem := amount*basisPoints/10000, amount*basisPoints%10000
	if 2*rem < 10000 {{
		return q
	}}
{tie}	return q + 1
}}
'''
    return {"money.go": src}

def retry(ver):
    note = {"v1.2.1": "// v1.2.1: attempts below 1 are treated as 1.\n",
            "v1.2.3": "// v1.2.3: the wait between attempts is capped at 5s.\n"}.get(ver, "")
    cap = "\t\tif wait > 5*time.Second {\n\t\t\twait = 5 * time.Second\n\t\t}\n" if ver == "v1.2.3" else ""
    src = f'''// Package retry retries a function with exponential backoff.
package retry

import (
	"context"
	"time"
)

{note}// Do calls fn up to attempts times, doubling the wait from base after each
// failure, and stops early when ctx is done.
func Do(ctx context.Context, attempts int, base time.Duration, fn func() error) error {{
	var err error
	wait := base
	for i := 0; i < attempts; i++ {{
		if err = fn(); err == nil {{
			return nil
		}}
		if i == attempts-1 {{
			break
		}}
{cap}		select {{
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(wait):
		}}
		wait *= 2
	}}
	return err
}}
'''
    return {"retry.go": src}

def uuidx(ver):
    # v1.1.0 Parse indexes before checking the length (GO-2026-0152).
    check = "\tif len(s) != 36 {\n\t\treturn nil, ErrFormat\n\t}\n" if ver == "v1.2.0" else ""
    parse = f'''
// ErrFormat is returned by Parse for a string that is not a UUID.
var ErrFormat = errors.New("uuidx: bad format")

// Parse returns the 16 bytes of a UUID in its 36-character text form.
func Parse(s string) ([]byte, error) {{
{check}	if s[8] != '-' || s[13] != '-' || s[18] != '-' || s[23] != '-' {{
		return nil, ErrFormat
	}}
	return hex.DecodeString(strings.ReplaceAll(s, "-", ""))
}}
'''
    extra = ('''
// NewString is New; kept for callers of the v1.2 name.
func NewString() string { return New() }
''' if ver == "v1.2.0" else "")
    src = '''// Package uuidx makes random version 4 UUIDs.
package uuidx

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
)

// New returns a random UUID string.
func New() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic(err)
	}
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}
''' + parse + extra
    return {"uuidx.go": src}

def xmlsafe(ver):
    return {"xmlsafe.go": '''// Package xmlsafe decodes XML documents into Go values.
package xmlsafe

import (
	"encoding/xml"
	"io"
)

// Decode reads one XML document from r into v.
func Decode(r io.Reader, v any) error {
	return xml.NewDecoder(r).Decode(v)
}
'''}

def router(ver):
    if ver.startswith("v2"):
        return {"router.go": '''// Package router is a thin method-aware wrapper over http.ServeMux.
//
// v2 breaking change: Handle takes the pattern first and the methods last.
package router

import "net/http"

// Router dispatches by method and path.
type Router struct{ mux *http.ServeMux }

// New returns an empty Router.
func New() *Router { return &Router{mux: http.NewServeMux()} }

// Handle registers h for pattern and each of methods (all methods if none).
func (r *Router) Handle(pattern string, h http.Handler, methods ...string) {
	if len(methods) == 0 {
		r.mux.Handle(pattern, h)
		return
	}
	for _, m := range methods {
		r.mux.Handle(m+" "+pattern, h)
	}
}

func (r *Router) ServeHTTP(w http.ResponseWriter, req *http.Request) { r.mux.ServeHTTP(w, req) }
'''}
    return {"router.go": '''// Package router is a thin method-aware wrapper over http.ServeMux.
package router

import "net/http"

// Router dispatches by method and path.
type Router struct{ mux *http.ServeMux }

// New returns an empty Router.
func New() *Router { return &Router{mux: http.NewServeMux()} }

// Handle registers h for method and pattern.
func (r *Router) Handle(method, pattern string, h http.Handler) {
	r.mux.Handle(method+" "+pattern, h)
}

func (r *Router) ServeHTTP(w http.ResponseWriter, req *http.Request) { r.mux.ServeHTTP(w, req) }
'''}

MODULES = {
    "mods.example.com/jwtkit": (jwtkit, [("v1.4.0", "2026-02-10"), ("v1.4.2", "2026-09-17"), ("v1.5.0", "2026-09-17")]),
    "mods.example.com/money": (money, [("v1.6.0", "2026-01-15"), ("v1.7.0", "2026-05-28")]),
    "mods.example.com/retry": (retry, [("v1.2.0", "2026-06-30"), ("v1.2.1", "2026-07-22"), ("v1.2.3", "2026-08-21")]),
    "mods.example.com/uuidx": (uuidx, [("v1.1.0", "2025-11-03"), ("v1.2.0", "2026-07-14")]),
    "mods.example.com/xmlsafe": (xmlsafe, [("v0.9.1", "2025-12-01")]),
    "mods.example.com/router": (router, [("v1.9.0", "2026-03-20")]),
    "mods.example.com/router/v2": (router, [("v2.0.0", "2026-08-05")]),
}

for path, (gen, versions) in MODULES.items():
    d = os.path.join(ROOT, path, "@v")
    os.makedirs(d, exist_ok=True)
    for ver, date in versions:
        # retry v1.2.3 was built for go 1.26; the build host and CI run go 1.25.
        goline = "1.26" if (path, ver) == ("mods.example.com/retry", "v1.2.3") else "1.25"
        gomod = f"module {path}\n\ngo {goline}\n"
        with open(os.path.join(d, ver + ".info"), "w") as f:
            json.dump({"Version": ver, "Time": date + "T09:00:00Z"}, f)
        with open(os.path.join(d, ver + ".mod"), "w") as f:
            f.write(gomod)
        prefix = f"{path}@{ver}/"
        with zipfile.ZipFile(os.path.join(d, ver + ".zip"), "w") as z:
            for name, body in sorted({"go.mod": gomod, "LICENSE": "BSD-3-Clause\n", **gen(ver)}.items()):
                zi = zipfile.ZipInfo(prefix + name, date_time=(2026, 1, 1, 0, 0, 0))
                z.writestr(zi, body)
    with open(os.path.join(d, "list"), "w") as f:
        f.write("".join(v + "\n" for v, _ in versions))
PY
# go.sum is in the fixture; if a checkout lost it (it matches .gitignore),
# rebuild it from the mirror so the tree builds under -mod=readonly.
if [ ! -f go.sum ]; then
  GOPROXY="file://$PWD/third_party/goproxy" GONOSUMDB=mods.example.com GOTOOLCHAIN=local \
    go mod tidy
fi
export GIT_AUTHOR_NAME="Dev One" GIT_AUTHOR_EMAIL="dev.one@example.com"
export GIT_COMMITTER_NAME="Dev One" GIT_COMMITTER_EMAIL="dev.one@example.com"
export GIT_AUTHOR_DATE="2026-09-21T10:00:00 +0530" GIT_COMMITTER_DATE="2026-09-21T10:00:00 +0530"
git init -q -b main
git add -A
git commit -q -m "chore: sync module mirror and vulndb snapshot (2026-09-20)"
