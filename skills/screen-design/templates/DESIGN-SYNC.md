# <Product>: pushing this bundle to Claude Design

<!-- Template guidance: written by screen-design to docs/design/DESIGN-SYNC.md
     next to design.json. It tells a person how to push the finished bundle
     into a shared design system with Claude Code's /design-sync command.
     The skill never runs that command: the push shows its own permission
     prompt with the exact file list and target, and that prompt is the only
     place a person sees what is about to land in a shared system. Fill it
     from design.json and the files on disk. Delete each comment when you
     fill its section. -->

Built by screen-design on <YYYY-MM-DD>, design bundle v<version>.
Nothing in this folder has been pushed anywhere. The push is one command
you run yourself.

## What to run

<!-- What: the command and where to run it from, in the order a person does it.
     Good: names the folder to start the session in; says the command lists
     the design-system projects or offers to create one; says to read the
     plan and the file list before approving, and that declining is safe.
     Example: "From a Claude Code session in docs/design, run /design-sync,
     pick the product's project, check the list, approve." -->

From a Claude Code session started in `docs/design/`:

```
/design-sync
```

It lists your design-system projects, or offers to create one. Pick the
target, read the plan it shows (every file and the folder it comes from),
and approve. Declining changes nothing.

## What is in the bundle

<!-- What: every file the push will carry, with a count, taken from the disk.
     Good: counts match design.json (screens) and the folder; tokens.css is
     named as the only file that declares a colour; anything that should not
     go (screenshots, console logs, CHANGES.md) is listed under "Leave out".
     Example: "screens/: 14 files across 3 features, each with every state
     at desktop and 375 px". -->

- `design-system.html`: the tokens and every component in every state, light and dark
- `tokens.css`: every colour, space, radius, shadow and duration; nothing else declares one
- `screens/`: <N> files across <F> features, one per screen, each with every state
- `index.html`: the gallery, for reading the bundle locally
- `design.json`: the manifest (brief, directions, sitemap, navigation, screens, concerns, audit)

Leave out: `screens/*/shots/`, `*.console.txt`, `screens/*/CHANGES.md`.

## Before you approve

<!-- What: the three checks a person makes before the push lands.
     Good: each check is a command or a file to open with the result it must
     show; the audit line is copied from bundle.py check, never retyped.
     Example: "bundle.py check prints 0 audit findings, 0 problems". -->

1. The audit ran on the files being pushed: `<bundle.py check count line, verbatim>`.
2. The concerns in `index.html` under "Raised while designing" are
   answered or accepted; open ones travel with the bundle.
3. The target project is the product's own, not a shared sandbox.

## After it lands

<!-- What: what changes once the bundle is in the design system, and how to
     update it next round.
     Good: says a later round is pushed the same way and replaces files by
     path; says to record the push (date, target) in the feature's CHANGES.md.
     Example: "Round 2 changed S-03; rerun bundle.py audit, then /design-sync". -->

Record the date and the target project in each feature's `CHANGES.md`.
A later round is pushed the same way: rerun the audit, then `/design-sync`.
