# design-system: resolving the direction, contrast, primitives, roles, type and shape

Read when: steps 1 to 5: before any token is written.

1. Resolve the direction: `$ARGUMENTS`, else the token source (root
`DESIGN.md` frontmatter tokens, else `direction` in the newest
`docs/design/variants/*/approved.json`; the mapping is in
`${CLAUDE_PLUGIN_ROOT}/references/impeccable.md`, section design-system),
else root `DESIGN.md` or `docs/design/DESIGN.md` as prose, else
`approved.json`, else the app's current styles read as the de facto
system, else ask once for a brief (product, audience, one memorable
thing, brand colour or face). Read it in full; list what it fixes (hue,
faces, density, shape, devices) and what it leaves free. `--lint-only`:
go to the lint section. Other inputs read as the direction: gstack
`design-consultation` writes a direction as DESIGN.md prose (no
frontmatter tokens, so it is not a token source) and GSD `gsd-ui-phase`
writes a UI-SPEC per phase.
2. **Measure the direction before designing.** Compute the contrast of
every pair it implies (brand fill behind its label, brand as link text
on page and card, brand as focus ring on the page) with
`scripts/contrast.py` or the WCAG formula. A failing pair keeps its
hue and moves in lightness until it passes (or swaps the label to a
dark one); the report gives the direction's ratio, the shipped ratio
and the alternative.
3. Colour primitives in oklch: accent hue from the direction; neutrals
at the hue the direction asks for (warm, cool, or the accent's) with
chroma 0.004 to 0.016; success, warning, danger, info at their own
hues; each scale 0 to 1000, hue held, lightness varied. Compute every
sRGB value with the snippet in `references/stack-bindings.md`; a value
that clips gets less chroma. Refuse the default looks (cream and
terracotta, near-black and acid green, purple-blue gradients) unless
the direction names one.
4. Roles for light, then dark designed on its own: surfaces lift with
lightness, accent one step lighter, chroma down 10 to 20 percent, text
near white not pure white. Never invert. Text pairs 4.5:1, focus
rings, borders that carry meaning and icons 3:1, in both modes.
Include the pairs the components render that the role table misses:
grep the class strings for each `text-*` on each `bg-*` actually used
together (`text-muted-foreground` on `bg-muted` is the usual failure:
muted text tuned to 4.6:1 on the page drops under 4.5 on a tinted
strip), every opacity-modified fill (`bg-primary/90`,
`bg-destructive/90`, `bg-secondary/80`: the token composited over the
surface it sits on) behind its label, link and ring on card.
5. Type and shape. A face the direction names is the face, with its
fallbacks and how it loads (self-hosted files, a link, or "still to
do" in the report); a different face is at most a proposal. When the
direction leaves the face free, choose one for this product rather
than a default (Inter, Roboto, Arial, system-ui). A mono for data,
ids and code; tabular figures wherever numbers align (times, money,
counts). Three to five sizes on one scale with the body size the
direction gives; two UI weights. Spacing on 4 or 8. Radius as a
hierarchy (control, container, overlay, full). Elevation 0 to 3 with
the rule for what may cast a shadow. Motion durations 80, 150, 240,
400, 700 with standard, enter, exit easings. Touch targets: when the
direction or the devices mean touch (tablets, kiosks, phones),
interactive controls reach 44 px (iOS) or 48 dp (Android); measure the
component sizes the screens use and list the ones below.
