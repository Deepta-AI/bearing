#!/usr/bin/env python3
"""House lint: no print() in src/, and no function longer than the limit in lint.cfg.

Usage: lint.py <dir>. Prints one line per problem and the count of files and
functions checked; exits 1 on a problem or when it checked zero files.
"""

import ast
import configparser
import pathlib
import sys


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "src")
    cfg = configparser.ConfigParser()
    cfg.read("lint.cfg")
    limit = cfg.getint("lint", "max_function_lines")
    files = sorted(root.rglob("*.py"))
    problems, funcs = [], 0
    for path in files:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                funcs += 1
                length = node.end_lineno - node.lineno + 1
                if length > limit:
                    problems.append(f"{path}:{node.lineno}: {node.name} is {length} lines (limit {limit})")
            if isinstance(node, ast.Call) and getattr(node.func, "id", None) == "print":
                problems.append(f"{path}:{node.lineno}: print() in library code")
    for p in problems:
        print(p)
    print(f"lint: {len(files)} files, {funcs} functions, {len(problems)} problems")
    if not files:
        return 1
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
