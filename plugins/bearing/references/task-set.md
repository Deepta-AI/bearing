# Task sets: one task across repositories

A task set is one task id worked in several repositories: a change to an
API and the client that calls it, say. Each repository keeps its own
branch, state file, progress file, gate run and merge request; what ties
them together is the id in the branch name and a `## Repos` section in
every member's progress file. Nothing else is shared on disk.

One session per repository. The sandbox lets a Bash call write only
inside the working repository, and no skill is granted `git -C`, so a
session cannot branch or commit in a sibling. Work moves between
repositories by opening a session in each. The skills that cite this
file run the commands; this file holds only the rules.

## Start

Run `start-task` in each repository with the same id, the same name, the
same type and the same `--repos` list. The first run settles the merge
order and prints the line to run in each sibling,
`start-task <ID> <Name> --type <type> --repos <list>`, with the list in
that order and this branch's type; a sibling run with that line creates
the same branch name and writes the same section. A name
in the list resolves through `docs/architecture/repo-plan.json`: the
entry's `path` when it has one, else `../<name>` beside this repository.
This repository's own name (its directory name, or the plan entry whose
path is `.`) is always `.`. A name the plan does not hold is taken as
`../<name>`, and a path that does not exist is reported, never created.

## Branch names

The same `<type>/<ID>-<PascalName>` in every member, with one type for the
whole set; the printed sibling line passes `--type` so a bugfix or hotfix
set does not start its siblings as `feature/`. The hooks and the guard
read the id from the branch name, and `progress.py set` looks for this
branch name in every member, so a member on a different name drops out
of the set.

## State and progress

The state file stays per repository, local and ignored, as for any task.
The committed `docs/progress/<ID>.md` in each member gains a `## Repos`
section, one item per repository, `<n>. <Name> (<path>)`, where `<n>` is
the merge order and `<path>` is relative to that member (`.` for itself,
`../ShopApi` for a sibling). Names and order are identical in every
member; only the paths differ. At most 8 repositories: the progress file
has to stay short. `progress.py set` reads the section and prints one
row per repository (`ready`, `merged`, `not ready: <reason>` or
`missing`, the row for `.` marked `(this repository)`) and a `set:`
summary line. `missing` means the path holds no git repository: the
sibling is not cloned there yet, or the path is wrong. Any `missing` row
makes `set` exit 1; the other rows are still printed.

## Merge order

Providers before consumers. With a repo plan, order by the `git_path`
group: Infrastructure, then Server, then Client, then anything else, ties
in plan order. Without a plan, the order given to `--repos`. The engineer
confirms it once with AskUserQuestion, attended, whenever more than one
repository is listed (one question, that order recommended); a sibling
run with the printed line asks the same one question with the settled
order first. Unattended, the given order stands, nothing is asked, and
the report says so. Each MR must merge alone, in that order, and leave
its default branch working: expand first, contract later. A change
that cannot merge alone (a breaking API change both sides need at once)
goes under Risk in the description, with the two ways out:
`api-versioning` or `feature-flags`.

## One MR per repository

Each member gets its own MR from its own session. The description holds
a Task set block: each repository, its branch, its place in the order and
"merge after <Name>" (or "first"). The engineer merges, one MR at a time,
in order; a member is ready to merge when every member before it is
`ready` or `merged`.

The definition of done's task set item reads the `progress.py set` rows:
`pass` when every repository before this one in the merge order is
`ready` or `merged` (the first in the order always passes), `fail`
naming each one that is not, with its reason; a repository after this
one does not count, even when its path is `missing`. When the `## Repos`
section has no row whose path is `.`, the item is
`fail: no row for this repository` (the section was copied from a
sibling unedited). Without a `## Repos` section the item is
`n/a: not a task set`.

## Finish

The set is finished when every member's progress Status is `merged`. The
engineer sets it after each merge, as for any task; `progress.py set`
shows the count, and `workflow` in each member lists the task as in
flight until its own Status is `merged`.
