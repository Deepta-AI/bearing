# csvx

csvx is a robust, lightweight tool that lets you seamlessly filter product review exports {{EMDASH}} no spreadsheet required.

## Usage

```
python3 -m csvx reviews.csv out.csv --min-rating excellent
```

Ratings are ordered poor, fair, good, excellent. `--min-rating` keeps rows with that rating and every rating above it, so `--min-rating good` keeps good and excellent reviews.

When no row matches, csvx writes no file and prints:

```
0 rows matched {{EMDASH}} nothing written
```

## Options

| Option | Default | What it does |
|---|---|---|
| `--min-rating` | `poor` | Lowest rating to keep |
| `--batch-size` | `500` | Rows written between flushes to disk |
| `--columns` | {{EMDASH}} | Comma-separated columns to keep; all columns when unset |

Large exports are fine: rows are written in batches, so memory use stays flat however big the input is.

It's worth noting that csvx leverages Python's standard `csv` module, so quoting and embedded newlines are handled comprehensively.

See [docs/export.md](docs/export.md) for how an export runs.

Run the tests with `make check`.
