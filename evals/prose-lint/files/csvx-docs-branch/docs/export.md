# How an export runs

The export {{EMDASH}} read, filter, write {{EMDASH}} happens in one pass over the input.

csvx reads the input CSV, drops every row rated below `--min-rating`, and writes the rest to the output in batches of `--batch-size` rows (500 by default), flushing to disk after each batch. This ensures the output file is always in a consistent state.

If an export is interrupted, rerunning it with the same arguments should work: csvx picks up after the last batch it flushed, so rows already written are not written twice.

Certainly the simplest way to check a result is to count the rows: the command prints how many it wrote.
