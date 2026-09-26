package cli

import (
	"flag"
	"fmt"
	"io"
	"log/slog"
)

// runGreet is the example subcommand: replace it with the tool's first real
// one and keep its shape (own FlagSet, positional arguments refused, the
// result written to stdout and that write checked).
func runGreet(args []string, stdout, stderr io.Writer, log *slog.Logger) int {
	fs := flag.NewFlagSet(name+" greet", flag.ContinueOnError)
	who := fs.String("name", "world", "who to greet")
	if code, done := parse(fs, args, stdout, stderr, greetUsage); done {
		return code
	}
	if fs.NArg() > 0 {
		printf(stderr, "%s greet: unexpected argument %q\n\n", name, fs.Arg(0))
		greetUsage(stderr, fs)
		return ExitUsage
	}
	if _, err := fmt.Fprintf(stdout, "hello, %s\n", *who); err != nil {
		log.Error("greet: write output", "err", err)
		return ExitError
	}
	return ExitOK
}

func greetUsage(w io.Writer, fs *flag.FlagSet) {
	printf(w, "Usage: %s greet [-name NAME]\n\nFlags:\n", name)
	fs.SetOutput(w)
	fs.PrintDefaults()
	fs.SetOutput(io.Discard)
}
