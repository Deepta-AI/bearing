---
name: client-deliverables
description: 'Builds the client documentation pack: numbered folders, each document as Markdown, CSV and versioned Word, and a delivery checklist. Use when asked to "build the client pack" or "export the docs to Word".'
argument-hint: "[--customer <name>] [--summary <what changed>] [--import-checklist <filled.xlsx>]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(git status:*), Bash(git log:*), Bash(git check-ignore:*), Bash(git config user.name), Bash(uv run --quiet --with python-docx --with openpyxl python3 *skills/client-deliverables/scripts/pack.py*), Bash(uv run --quiet --with python-docx python3 *skills/client-deliverables/scripts/md2docx.py*)
---

# client-deliverables

The repository holds the truth; the client receives a folder. This skill
turns the first into the second without retyping: every Bearing artifact
goes into its numbered folder as the Markdown it was written in, as CSV
where a tracker or a test tool will import it, and as a Word document with
a cover, a version history and "About this document". Versions move only
when a source changed, so the history says what really changed.

Not this: the artifacts are written by their own skills (`prd`,
`backlog`, `high-level-design`, `data-model`, `test-cases` and the rest);
`client-handover` writes the end-of-engagement pack, which this skill
files under 11_Client_Deliverables. It never uploads anything: the engineer
puts the folder on the project's Drive.

## Inputs

- Manifest: looks in `docs/deliverables/pack.json`; if absent, the kit's
  `templates/pack.json` (the twelve folders and where each Bearing
  artifact goes). Copy it to the repository to add or move an artifact.
- Project and customer: `--customer`, then the manifest's `project` and
  `customer`; if absent, the project comes from the repository folder name
  and the customer is asked once ("who is the customer, as the cover
  should name them?"); no answer: "not recorded" on the cover.
- Prepared by: `.bearing/company.json` `delivering_entity` (`company-attribution`);
  if absent, `legal_name`, else `git config user.name`.
- Versions: `docs/deliverables/versions.json`, created on the first run
  and committed; history rows are never edited.
- Checklist: `templates/delivery-checklist.json` (154 tasks in twelve
  phases, the evidence that completes each) and the state in
  `docs/deliverables/checklist.json`; a filled workbook comes back with
  `--import-checklist <file.xlsx>`; if none, every task without evidence
  stays Not Started.
- Diagrams: the PNGs `architecture-diagram` renders; if absent, a
  diagram line becomes a pointer to the source and the report counts it.
- Scripts: `scripts/pack.py` and `scripts/md2docx.py` in this skill; they
  need `uv` for python-docx and openpyxl. No `uv`: stop with "install uv
  (https://docs.astral.sh/uv/) or run pack.py in an environment with
  python-docx and openpyxl".

## Steps

1. `git status`: uncommitted changes to `docs/` mean the pack would ship
   a draft. Say which files and ask whether to continue; the pack is
   built only from what the engineer agrees to ship.
2. Read the manifest and list which artifacts have a source and which do
   not; an artifact without a source is left out and named in the
   report, never written as an empty document.
3. Before building, read the artifacts that will change version (their
   source differs from `versions.json`) for leftovers a client must not
   see: template guidance comments are stripped by the script, but
   `<placeholder>` text, "TBD" in a cover field, "UNDEFINED" and
   "assumption:" lines stay. List each with file and line; the engineer
   decides whether to ship it. Ask once for `--summary` when the change
   deserves words ("Priced for 3 environments"); otherwise the script
   counts sections and ids added, expanded and retired.
4. Build: `uv run --quiet --with python-docx --with openpyxl python3 "${CLAUDE_PLUGIN_ROOT}/skills/client-deliverables/scripts/pack.py"`
   with `--customer`, `--summary` and `--import-checklist` as given. It
   rebuilds `deliverables/<Project>_ProjectDocumentation/` in full,
   writes the Word documents, CSVs, folder READMEs, the top README of
   current versions, `CHANGELOG.md` and
   `<Project>_DeliveryChecklist_<date>.xlsx`, and updates
   `docs/deliverables/versions.json` and `checklist.json`. It exits 1
   when no source exists or a document could not be written; fix the
   cause and rerun, never ship a pack with a problem line.
5. One Word document on its own, when asked for a single artifact:
   `uv run --quiet --with python-docx python3 "${CLAUDE_PLUGIN_ROOT}/skills/client-deliverables/scripts/md2docx.py" <source.md> <out.docx> --title <T> --project <P>`.
6. The pack is generated, so `pack.py` ignores it with the root-anchored
   rule `/deliverables/` and rewrites a bare `deliverables/` line, which
   would also ignore `docs/deliverables/` and leave the versions and
   checklist state uncommittable. Confirm with
   `git check-ignore docs/deliverables/versions.json`: it must print
   nothing before you print the commit step.
7. Print the output contract and the command for the engineer: commit
   `docs/deliverables/`, then upload the whole folder to the project's
   Drive, replacing the previous one.

## Output contract

```
## Deliverables: deliverables/<Project>_ProjectDocumentation/
pack: <pack.py counts line, verbatim>
New versions: <artifact> v<N> (<summary>), ... | none
Left out (no source): <artifact>, ... | none
Diagrams shown as pointers: N (run architecture-diagram for the PNGs) | 0
Leftovers shipped with the engineer's yes: <file:line>, ... | none
Checklist: <tasks>, <completed from evidence>, <set by people>
Next: commit docs/deliverables/, then upload the folder to Drive (replace, do not merge)
```

## Gotchas

- The folder is rebuilt, not updated. A file someone added inside it by
  hand is gone after the next run; it belongs in `docs/handover/` or
  `docs/meetings/`, which the manifest copies.
- A version bump is a promise that the content changed. Rebuilding twice
  bumps nothing; editing whitespace in a source does bump it, so do not
  reformat artifacts on the day of a delivery.
- Evidence marks a task Completed only because a file exists. It never
  overrides a status a person set in the workbook, and a person's
  Completed stays even when the evidence goes; import the filled
  workbook before rebuilding or the people's statuses are lost.
- Word cannot show SVG or Mermaid. The document embeds the PNG beside an
  SVG and puts a pointer where a Mermaid block has no rendered image;
  it never pastes diagram source as text.
- The cover names the customer. Get the spelling from the engineer, not
  from the repository name.
