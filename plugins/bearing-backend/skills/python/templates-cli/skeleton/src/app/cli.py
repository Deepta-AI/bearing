"""Command-line entry point for __REPO_NAME__.

`main` parses argv, runs one subcommand and returns the exit code: 0 on
success, 1 when the command failed, 2 on a usage error (argparse's own
code). Results go to stdout so they can be piped; errors go to stderr. The
console script `__REPO_SLUG__` and `python -m app` both call it.

Add a subcommand by writing a handler that takes the parsed namespace and
returns an exit code, then registering it in `build_parser`. A handler raises
`CommandError` for a failure the user can act on; anything else is a bug and
keeps its traceback.
"""

import argparse
import sys
from collections.abc import Callable
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path

PROG = "__REPO_SLUG__"
DESCRIPTION = "__REPO_NAME__ command-line tool."

EXIT_OK = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2

Handler = Callable[[argparse.Namespace], int]


class CommandError(Exception):
    """A command failed for a reason the user can act on. `main` prints it and returns 1."""


def package_version() -> str:
    """The installed distribution's version; a source tree that was never installed says so."""
    try:
        return version(PROG)
    except PackageNotFoundError:
        return "0+unknown"


def count_lines(args: argparse.Namespace) -> int:
    """`lines PATH...`: print each file's line count, then a total for more than one file."""
    paths: list[Path] = args.paths
    total = 0
    for path in paths:
        try:
            with path.open("rb") as handle:
                n = sum(1 for _ in handle)
        except OSError as exc:
            raise CommandError(f"{path}: {exc.strerror or exc}") from exc
        total += n
        sys.stdout.write(f"{n}\t{path}\n")
    if len(paths) > 1:
        sys.stdout.write(f"{total}\ttotal\n")
    return EXIT_OK


def build_parser() -> argparse.ArgumentParser:
    """The parser with every subcommand registered; each sets `handler` as its default."""
    parser = argparse.ArgumentParser(prog=PROG, description=DESCRIPTION)
    parser.add_argument("--version", action="version", version=f"%(prog)s {package_version()}")
    commands = parser.add_subparsers(dest="command", metavar="COMMAND", required=True)

    lines = commands.add_parser("lines", help="count the lines in one or more files")
    lines.add_argument("paths", nargs="+", type=Path, metavar="PATH", help="a file to read")
    lines.set_defaults(handler=count_lines)
    return parser


def main(argv: list[str] | None = None) -> int:
    """Parse `argv` (default `sys.argv[1:]`), run the subcommand and return its exit code."""
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
    except SystemExit as exc:
        # argparse exits on --help, --version (0) and on a usage error (2,
        # message already on stderr). Returning the code keeps main testable.
        return exc.code if isinstance(exc.code, int) else EXIT_USAGE
    handler: Handler = args.handler
    try:
        return handler(args)
    except CommandError as exc:
        sys.stderr.write(f"{PROG}: error: {exc}\n")
        return EXIT_FAILURE
