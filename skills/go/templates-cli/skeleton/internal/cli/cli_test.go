package cli

import (
	"bytes"
	"errors"
	"strings"
	"testing"
)

func TestRun(t *testing.T) {
	cases := []struct {
		name       string
		args       []string
		wantCode   int
		wantStdout string // substring; empty means stdout must be empty
		wantStderr string // substring; empty means stderr must be empty
	}{
		{name: "greet defaults to world", args: []string{"greet"}, wantCode: ExitOK, wantStdout: "hello, world\n"},
		{name: "greet takes a name", args: []string{"greet", "-name", "Ada"}, wantCode: ExitOK, wantStdout: "hello, Ada\n"},
		{name: "greet takes a double-dash flag", args: []string{"greet", "--name=Ada"}, wantCode: ExitOK, wantStdout: "hello, Ada\n"},
		{name: "--version prints the version", args: []string{"--version"}, wantCode: ExitOK, wantStdout: "__REPO_SLUG__ test-version\n"},
		{name: "-version wins over a command", args: []string{"-version", "greet"}, wantCode: ExitOK, wantStdout: "__REPO_SLUG__ test-version\n"},
		{name: "help goes to stdout", args: []string{"help"}, wantCode: ExitOK, wantStdout: "Usage: __REPO_SLUG__"},
		{name: "-h goes to stdout", args: []string{"-h"}, wantCode: ExitOK, wantStdout: "Commands:\n  greet"},
		{name: "greet -h lists its flags", args: []string{"greet", "-h"}, wantCode: ExitOK, wantStdout: "-name"},
		{name: "-v logs debug to stderr", args: []string{"-v", "greet"}, wantCode: ExitOK, wantStdout: "hello, world\n", wantStderr: "running command"},
		{name: "no command is a usage error", args: nil, wantCode: ExitUsage, wantStderr: "no command given"},
		{name: "unknown command is a usage error", args: []string{"frobnicate"}, wantCode: ExitUsage, wantStderr: `unknown command "frobnicate"`},
		{name: "bad global flag is a usage error", args: []string{"--nope"}, wantCode: ExitUsage, wantStderr: "flag provided but not defined: -nope"},
		{name: "bad command flag is a usage error", args: []string{"greet", "--nope"}, wantCode: ExitUsage, wantStderr: "Usage: __REPO_SLUG__ greet"},
		{name: "stray argument is a usage error", args: []string{"greet", "extra"}, wantCode: ExitUsage, wantStderr: `unexpected argument "extra"`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			setVersion(t, "test-version")
			var stdout, stderr bytes.Buffer

			code := Run(tc.args, &stdout, &stderr)

			if code != tc.wantCode {
				t.Fatalf("exit code: got %d want %d\nstdout: %s\nstderr: %s", code, tc.wantCode, stdout.String(), stderr.String())
			}
			checkStream(t, "stdout", stdout.String(), tc.wantStdout)
			checkStream(t, "stderr", stderr.String(), tc.wantStderr)
			if tc.wantCode == ExitUsage && !strings.Contains(stderr.String(), "Usage: ") {
				t.Fatalf("a usage error must print usage on stderr, got: %s", stderr.String())
			}
		})
	}
}

// A result that cannot be written is a failed command, exit 1, not a
// silent success.
func TestRunGreetWriteFailure(t *testing.T) {
	var stderr bytes.Buffer

	code := Run([]string{"greet"}, failingWriter{}, &stderr)

	if code != ExitError {
		t.Fatalf("exit code: got %d want %d", code, ExitError)
	}
	if !strings.Contains(stderr.String(), "write output") {
		t.Fatalf("stderr should name the failure, got: %s", stderr.String())
	}
}

func checkStream(t *testing.T, which, got, want string) {
	t.Helper()
	if want == "" {
		if got != "" {
			t.Fatalf("%s: want empty, got: %s", which, got)
		}
		return
	}
	if !strings.Contains(got, want) {
		t.Fatalf("%s: want it to contain %q, got: %s", which, want, got)
	}
}

func setVersion(t *testing.T, v string) {
	t.Helper()
	old := Version
	Version = v
	t.Cleanup(func() { Version = old })
}

type failingWriter struct{}

func (failingWriter) Write([]byte) (int, error) { return 0, errors.New("disk full") }
