# tracker-sync: sync and create, item by item

Read when you run sync or create and need the full text of the existing-key search, duplicate search, hierarchy, readiness, bodies, counts and write-back items.

2. **Existing keys, in every form.** An item is already in the tracker if
   anything ties a project key to it: its `Ticket:` line, any other
   `Jira:`/`Issue:`/`Key:` line or a key in its heading or text, a commit
   subject or body (`git log --all --format='%h %s%n%b' | grep '<PREFIX>-[0-9]'`),
   or a code or test comment naming the item's id or
   title (`grep -rn '<PREFIX>-[0-9]'`). Say what tied each key to its
   item. A key found only in history or code is still a key: no second
   ticket; propose recording it in the backlog.
3. **Duplicates the repository cannot show.** An item with no key
   anywhere may still have been filed by hand. When reachable, `brg-tracker list --q "<title words>"`
   for each before creating; when not, say this
   search is the first step of the filing run.
4. **Hierarchy.** Epics first, then stories with `--parent <epic key>`,
   then test cases under their story. An existing ticket whose epic is new
   is re-parented once the epic exists, not created again; `update` has no
   `--parent`, so `link` it to the epic and list the parent change for the
   user to make in the tracker.
5. **Readiness.** Hold an item back (report it, do not file it as ordinary
   work) when an acceptance criterion contradicts an Accepted ADR, a stated
   constraint or another item: name the criterion, the decision, and what
   would unblock it (rewrite the criterion, or a superseding ADR). Raising
   the conflict is yours; settling it is the user's, so no ADR or story
   text is edited. Flag items with no acceptance criteria.
6. **Bodies.** For each item to create, write its description file:
   narrative, every acceptance criterion with its `AC-` id verbatim,
   non-goals, its `TC-` ids, the ADRs it rests on. Every
   `--description-file` you name must exist when you finish.
7. **Counts.** Already in the tracker (keys, and how each was found), to
   create (epics, stories, test cases), held back, pending as uncommitted.
   Check they add up to the items in the backlog.
7a. **Story to PRD (rest).** When the PRD is published as a document
   (`brg-tracker docs --type prd`, or Step 3c in the same run), create
   every story with `--document <PRD id>` and give existing story tickets
   the same with `update`, so each story opens on the requirements it
   came from.
8. **Write-back, only with real keys.** When a create returns a key,
   record it as the repository's convention says (`Ticket: <KEY>`) and
   leave that change uncommitted for the user. Never write a placeholder,
   a guessed next number or a status note into the backlog.
