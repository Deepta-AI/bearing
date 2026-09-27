# How an export runs

csvx reads the whole input CSV into memory, drops every row rated below `--min-rating`, and writes the rest to the output in batches of `--batch-size` rows (500 by default), flushing to disk after each batch.

The output is opened for writing from the start, so rerunning an interrupted export starts over and replaces the partial file.
