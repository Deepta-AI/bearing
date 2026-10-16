# tracker-sync: publishing the repository's documents (rest)

Read when you run the docs subcommand or Step 3c in a sync.

Publishes the project's documents as tracker documents, so the PRD, the
decisions and the plan sit beside the tickets. Run it before `sync` on a
first filing, so stories can point at the PRD.

1. **What to publish, in this order.** Each file that exists and is
   committed; an uncommitted one is named and skipped unless the user says
   otherwise:
   - `docs/product/PRD.md` as `prd`;
   - `docs/product/questions.md`, `backlog.md`, `coverage.md`,
     `user-flows.md`, `estimate.md`, `IMPORT.md` and `docs/decisions.md`
     as `doc`;
   - an "Architecture decisions" document as `design` (`--source
     docs/adr`, its content the decision log, or one line per ADR when
     there is no log), then every `docs/adr/*.md` as `design` with
     `--parent` set to its id;
   - `docs/architecture/*.md` (high- and low-level designs) as `design`.
2. **One call per file:** `brg-tracker doc-put --title "<the file's first
   # heading>" --file <path> --source <path> --type <t>`. The source
   marker makes a rerun update the same document, renamed or not, and an
   unchanged file is reported `unchanged` with nothing written.
3. **Never** call the tracker's own story generation from a document:
   `backlog` owns the stories, and generated ones would duplicate them.
4. `documents: not supported` (exit 3) is a skip, reported, not a failure;
   `this tracker does not support documents` (exit 1) means the server
   lacks the optional endpoints: report it and file the tickets anyway.
