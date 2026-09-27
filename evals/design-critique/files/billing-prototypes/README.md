# Tallybook

Invoicing for small design studios: send an invoice, see who has paid,
nudge who has not.

The web app is not started yet. This repository holds the product design:

- `DESIGN.md`: the design system (type, colour, spacing) every screen follows.
- `docs/design/tokens.css`: the colour and spacing tokens, shared by every prototype.
- `docs/design/flows/<feature>/flows.md`: each screen's job, its states and its copy.
- `docs/design/<feature>/`: static HTML prototypes, one file per screen and state.

`make check` runs the prototype checker (every page has a language, a title,
a viewport, resolves its stylesheet links and defines every token it uses).

Prototypes are shown to the client as they are, opened straight from disk.
