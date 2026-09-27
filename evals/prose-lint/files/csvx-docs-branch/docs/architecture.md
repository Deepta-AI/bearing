# Architecture

csvx is two modules {{EMDASH}} `cli.py` parses arguments and `export.py` does the work.

The reader and writer are Python's `csv` module; there is no third-party dependency {{EMDASH}} keep it that way so the tool runs anywhere Python 3 does.
