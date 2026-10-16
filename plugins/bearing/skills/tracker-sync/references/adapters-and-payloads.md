# tracker-sync: background, adapter facts and the no-tracker payload files

Read when you read an adapter header, or the tracker is unreachable and payloads and commands are printed.

The script is the easy part. The value of this skill is deciding what is
true before anything is sent: which items already exist in the tracker,
which are not ready to file, what status the repository's own rules allow,
and whether the ticket's promises are actually met on the branch. Do that
analysis in full whether or not a tracker is reachable.

The document commands exist on the REST tracker only (any
server implementing the optional documents part of the protocol); on Jira,
GitLab and GitHub they print `documents: not supported` and exit 3. On rest,
`create` and `update` also take `--document <id>`.

Adapter facts (hierarchy, how `--parent` maps, status names, what "link"
means on GitHub, the configuration keys each adapter needs) are in the
header comment of `bin/brg-tracker` and of each adapter script; read the
one for the configured tracker. The REST tracker protocol is in
`docs/TRACKERS.md` of the Bearing repository, which the plugin does not
ship.

```
brg-tracker create --type epic --title "Notifications" --description-file .scratch/tracker/E3.md
brg-tracker create --type story --title "..." --parent <E3 key> --description-file .scratch/tracker/NTF-2.md
brg-tracker link PROJ-88 relates <E3 key>         # already filed; set its parent to E3 by hand
brg-tracker comment PROJ-88 --file .scratch/tracker/PROJ-88-trace.md
```

README, CONTRIBUTING, the backlog header: the project key and tracker URL,
where keys are recorded, the status workflow and the condition for each
status, the long-lived branch, how tests carry test case ids. These
override every default in SKILL.md (Steps 3 to 4).
