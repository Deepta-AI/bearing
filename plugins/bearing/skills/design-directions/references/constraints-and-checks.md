# design-directions: constraints, the react-shadcn theme idea and the step 8 checks

Read when you list project constraints (step 1), explain why a direction is a theme, or compute contrast pairs (step 8).

On React with shadcn/ui and Tailwind, a direction is a theme, not a page:
it overrides the variables the components already read, and the real
screens render with it switched on. The comparison is then like for like:
the same screens, the same components, three looks. A direction the
component set cannot render is not a direction.

- Project constraints, which override every default in this skill:
  accepted ADRs under `docs/adr/`, the Content-Security-Policy (an
  `index.html` meta tag or server headers), the README's hardware and
  deployment notes, brand notes. Look for: where fonts may come from (a
  `font-src 'self'`, a firewalled or offline deployment), a fixed device
  size or orientation, light only, a contrast ratio above WCAG AA, a
  touch-target floor, a motion limit, privacy rules on what a screen may
  show. A brand note never outranks an Accepted ADR.

1. Read the inputs; print each as read or absent, then list the
   constraints found with their source (for example "fonts: self-hosted
   only, ADR-0003 and CSP font-src 'self'"; "device: 1080 x 1920
   portrait, light only, README and ADR-0005"). They replace the
   defaults: widths 375, 768 and 1440 become the device size when the
   product runs on one; both themes become one when a rule says so; 44 px
   targets, 4.5:1 and 200 to 700 ms motion become the project's numbers
   when stricter. Zero screens and no brief: stop with "provide flows,
   stories, code with screens, or a brief".

- Contrast, computed from the values written, in every theme the
  product has, against the project's ratios. HTML pages:
  `python3 "${CLAUDE_PLUGIN_ROOT}/skills/design-critique/scripts/pairs.py" --need <body ratio> <n>-<name>.html...`
  (its large-text threshold is 3:1; apply a stricter project rule by
  hand). react-shadcn: compute foreground on background and card,
  primary-foreground on primary, muted-foreground on background, card
  and muted, and every status pair, per direction and theme. Print the
  count; zero pairs checked is a failure, not a pass.

Examples of the user and condition a direction serves first: a dispatcher at a desk all day, a driver in sun on a phone, a patient at arm's length.
