// Command __REPO_SLUG__ is the __REPO_NAME__ command-line tool. It hands the
// arguments and the output streams to internal/cli and exits with the code
// it returns, and nothing else.
package main

import (
	"os"

	"__MODULE__/internal/cli"
)

// version is set at build time: -ldflags "-X main.version=v1.2.3".
var version = "dev"

func main() {
	cli.Version = version
	os.Exit(cli.Run(os.Args[1:], os.Stdout, os.Stderr))
}
