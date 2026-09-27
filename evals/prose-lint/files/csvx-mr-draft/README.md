# csvx

csvx filters a product review export by rating and writes the rows it keeps to a new CSV.

## Usage

```
python3 -m csvx reviews.csv out.csv --min-rating excellent
```

Ratings are ordered poor, fair, good, excellent. `--min-rating` keeps rows with that rating and every rating above it, so `--min-rating good` keeps good and excellent reviews.

When no row matches, csvx writes no file and prints a line saying 0 rows matched.

## Options

| Option | Default | What it does |
|---|---|---|
| `--min-rating` | `poor` | Lowest rating to keep |
| `--batch-size` | `500` | Rows written between flushes to disk |
| `--columns` | none | Comma-separated columns to keep; all columns when unset |

Reading and writing use Python's standard `csv` module, so quoting and embedded newlines follow its rules.

See [docs/export.md](docs/export.md) for how an export runs.

Run the tests with `make check`.
