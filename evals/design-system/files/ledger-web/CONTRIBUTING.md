# Contributing

## Styling

- Colours come from the custom properties in `src/styles/tokens.css`.
- Spacing is any multiple of 4px.
- Font sizes come from `--font-size-*`.

## Checks

Everything that gates a merge runs from `make check`, which CI runs on
every merge request. Every check prints how many things it examined and
fails when that number is zero: a check that looked at nothing did not
pass.
