"""Remove trailing whitespace from one file in place."""
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    lines = fh.read().split("\n")
with open(path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(line.rstrip() for line in lines))
