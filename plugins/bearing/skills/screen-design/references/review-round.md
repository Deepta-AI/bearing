# screen-design: a review round

Read when client or team comments arrive on screens that already exist.

### A review round (client or team comments)

1. Find where the pages really come from. When they are generated (a
build script, a JSON source), rebuild with the repository's command
and `git diff` the pages: a line the rebuild changes is a hand edit
made to the output (`git log` on the page names who and why). Port
every such edit into the source first and rebuild until the diff is
empty. From then on edit the source and rebuild; an edit to a
generated page is lost at the next rebuild.
2. Triage every comment before editing anything, against the PRD's scope,
the Accepted ADRs, the flows, what the code does (does the state the
client wants dropped actually occur, and for which inputs) and the
accessibility floor. Each gets a verdict: applied, applied with a
change, or not applied, with the reason and, when not applied, the
question back. A comment about a screen that does not exist: say so,
name the designed screen it most plausibly means from what it
describes, and ask; never invent the screen.
3. Colour changes are measured, not eyeballed. Find every use of the
token, including tokens that alias it (`--color-focus: var(--color-primary)`,
borders, link text), and measure each rendered
pair with
`python3 "${CLAUDE_PLUGIN_ROOT}/skills/accessibility/scripts/contrast.py" FG:BG[:MIN]...`:
text 4.5:1 (3:1 at 24 px, or 18.66 px bold), focus rings and control
boundaries 3:1 against the colour next to them. Keep the requested
colour where it can pass and fix its partner (dark text on a light
brand green; the focus token on its own darker value); state the
ratios in the reply.
4. When rewording a state that stays, keep its facts (every cause the
code has for it). A mockup change the app does not do yet (a time
format, a new control) is named as build work with the file that would
change.
5. Change only what the comments need. After the rebuild, pages no
comment touches are byte-identical.
6. Append the round to `CHANGES.md` (comment, verdict, change,
`file:line`), rerun the gates, re-shoot touched screens when browse is
executable. Stop when the user says done, or after three rounds with no
new comment.
