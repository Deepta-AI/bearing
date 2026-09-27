// Package flagx parses command-line flags with environment fallbacks.
package flagx

import (
	"flag"
	"os"
)

// String defines a string flag whose default comes from env when set.
func String(fs *flag.FlagSet, name, env, def, usage string) *string {
	if v, ok := os.LookupEnv(env); ok {
		def = v
	}
	return fs.String(name, def, usage)
}
