// Package cli is the __REPO_NAME__ command line: global flags, subcommand
// dispatch, usage text and exit codes. main passes it the arguments and the
// output streams, so every path through it runs in a test without a process.
package cli

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"strings"
)

// Exit codes. 2 is the flag package's own code for a bad command line.
const (
	ExitOK    = 0 // the command did what was asked
	ExitError = 1 // the command ran and failed
	ExitUsage = 2 // the command line was wrong; usage went to stderr
)

// Version is what --version prints. main sets it from its own version
// variable, which the build fills with -ldflags "-X main.version=...".
var Version = "dev"

const name = "__REPO_SLUG__"

// command is one subcommand. run gets the arguments after its name and
// returns an exit code; it prints its own usage on a bad command line.
type command struct {
	name    string
	summary string
	run     func(args []string, stdout, stderr io.Writer, log *slog.Logger) int
}

// commands is the dispatch table, in the order usage lists them.
var commands = []command{
	{name: "greet", summary: "print a greeting", run: runGreet},
}

// Run parses args (without the program name), runs the chosen subcommand and
// returns the process exit code. Results go to stdout; usage, errors and
// logs go to stderr.
func Run(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet(name, flag.ContinueOnError)
	showVersion := fs.Bool("version", false, "print the version and exit")
	verbose := fs.Bool("v", false, "log debug detail to stderr")
	if code, done := parse(fs, args, stdout, stderr, usage); done {
		return code
	}
	if *showVersion {
		printf(stdout, "%s %s\n", name, Version)
		return ExitOK
	}

	level := slog.LevelWarn
	if *verbose {
		level = slog.LevelDebug
	}
	log := slog.New(slog.NewTextHandler(stderr, &slog.HandlerOptions{Level: level}))

	rest := fs.Args()
	if len(rest) == 0 {
		printf(stderr, "%s: no command given\n\n", name)
		usage(stderr, fs)
		return ExitUsage
	}
	if rest[0] == "help" {
		usage(stdout, fs)
		return ExitOK
	}
	for _, c := range commands {
		if c.name == rest[0] {
			log.Debug("running command", "command", c.name, "args", len(rest)-1)
			return c.run(rest[1:], stdout, stderr, log)
		}
	}
	printf(stderr, "%s: unknown command %q\n\n", name, rest[0])
	usage(stderr, fs)
	return ExitUsage
}

// parse runs fs over args with the flag package's own output silenced, so
// this package decides where usage goes: stdout for -h, stderr with the
// error for a bad flag. done is true when the caller should return code.
func parse(fs *flag.FlagSet, args []string, stdout, stderr io.Writer, usageFn func(io.Writer, *flag.FlagSet)) (code int, done bool) {
	fs.SetOutput(io.Discard)
	fs.Usage = func() {}
	err := fs.Parse(args)
	switch {
	case err == nil:
		return ExitOK, false
	case errors.Is(err, flag.ErrHelp):
		usageFn(stdout, fs)
		return ExitOK, true
	default:
		printf(stderr, "%s: %v\n\n", name, err)
		usageFn(stderr, fs)
		return ExitUsage, true
	}
}

func usage(w io.Writer, fs *flag.FlagSet) {
	var b strings.Builder
	fmt.Fprintf(&b, "Usage: %s [flags] <command> [command flags]\n\nCommands:\n", name)
	for _, c := range commands {
		fmt.Fprintf(&b, "  %-10s %s\n", c.name, c.summary)
	}
	fmt.Fprintf(&b, "  %-10s %s\n\nFlags:\n", "help", "print this text")
	fs.SetOutput(&b)
	fs.PrintDefaults()
	fs.SetOutput(io.Discard)
	fmt.Fprintf(&b, "\nRun '%s <command> -h' for a command's flags.\n", name)
	printf(w, "%s", b.String())
}

// printf writes to a terminal stream. A failed write to stdout or stderr has
// nowhere left to be reported, so the error is dropped here and only here;
// a command whose output is its result checks its own writes (see greet).
func printf(w io.Writer, format string, args ...any) {
	_, _ = fmt.Fprintf(w, format, args...)
}
