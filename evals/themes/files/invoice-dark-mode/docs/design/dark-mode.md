# Dark mode: design note

From the design team's Figma file "Invoices / Dark" (v3). Values are
final from our side; engineering picks up the switching.

## Rollout

Dark ships as the default for everyone at launch. People who want the
light look can switch back in Settings.

## Palette

Brand asked us to keep the brand blue exactly as it is in light, so
accent and focus stay #2f5bd3 in dark too.

| Token | Dark |
| --- | --- |
| --color-bg | #16171b |
| --color-surface | #1e2026 |
| --color-surface-raised | #262830 |
| --color-text | #e8e9ed |
| --color-text-muted | #7c808c |
| --color-border | #2c2f36 |
| --color-border-strong | #4a4e59 |
| --color-accent | #2f5bd3 |
| --color-accent-hover | #4169dc |
| --color-on-accent | #ffffff |
| --color-focus | #2f5bd3 |
| --color-danger | #ef5350 |
| --color-success | #66bb6a |
| --color-warning-subtle | #3a2e14 |

## Components

- Table row hover: #262830.
- Status badges (background / text): paid #1d3324 / #8fd19e,
  overdue #3b1f1f / #e35d52, draft #3a2e14 / #e0b25c.
- Invoice dialog: surface-raised.
- Revenue chart: axis labels #9a9eaa, grid #2c2f36, bars in the
  accent, danger and success colours.
