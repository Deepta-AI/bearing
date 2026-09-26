# Conventions for notes-cli

Read this before adding or changing a command.

- A command that finds nothing to show prints nothing and exits 0, the way
  `list` does on an empty store. Exit 1 is reserved for a failure the user
  must act on (a store that cannot be read), never for an empty result.
- A missing, empty or extra argument prints the usage line to stderr and
  exits 2. Every command shares the one usage line.
- Output lines have one shape: `<id>: <text>`, in stored order.
- Reading commands never write: `list` does not create notes.json, and
  neither may any other command that only reads.
- notes/store.py holds the data rules and never prints; notes/__main__.py
  parses arguments and prints.
- The standard library only. No new dependency, and `make check` stays the
  one gate, unchanged in what it runs.
