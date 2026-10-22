# The Bearing mark

`bearing-mark.svg` is the source: a B with a heading mark at its upper
right, white on an indigo tile (`#6168d2`, the accent in
`docs/design/tokens.json`). Both sites use it.

| Where | File | How |
| --- | --- | --- |
| Site header and drawer | `ui/shell.tsx` `Mark()` | inline, drawn with `--accent` and `--on-accent` |
| Favicon | `site/public/favicon.svg`, `devguide/public/favicon.svg` | copies of the source |
| Favicon fallback | `*/public/favicon-32.png` | 32 px render of the source |
| Home screen | `*/public/apple-touch-icon.png` | 180 px render of the source |
| Large use (slides, README) | `bearing-mark-512.png` | 512 px render of the source |

Rules:

- Keep the tile, the B and the heading mark together; do not use the B
  alone or recolour the tile.
- Leave at least a quarter of the mark's width clear on every side.
- Smallest size is 16 px; below 24 px use the SVG, not a scaled PNG.
- Beside the wordmark, set "Bearing" in Geist at weight 600 with -0.02em
  tracking, the mark the height of the capital B.

After changing the source, copy it to both `public/favicon.svg` files and
render the PNGs again from it at 32, 180 and 512 px (any SVG rasteriser;
headless Chrome works: `google-chrome --headless=new
--default-background-color=00000000 --window-size=N,N --screenshot=...`
on a page holding the SVG at N px).
