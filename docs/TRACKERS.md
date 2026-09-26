# Trackers

The ticket tracker is optional and configurable. One command surface,
`plugins/bearing/bin/brg-tracker`, fronts four adapters; the `tracker-sync` skill calls it
and nothing else. Three adapters speak to Jira, GitLab and GitHub; the
fourth, `rest`, speaks a small documented HTTP protocol (see
[REST tracker protocol](#rest-tracker-protocol)) so any tracker, including
an in-house one, can be connected by implementing a handful of endpoints.
No tracker is assumed: the default is `none`.

## Configuration

Everything lives in `~/.config/bearing/bearing.env` (`XDG_CONFIG_HOME`
respected; mode 600; never inside a repository). The installer writes it
from `plugins/bearing/templates/user/bearing.env` with placeholders; edit the values by
hand. Environment variables of the same name win over the file, so a CI
job or a one-off shell can override without editing it.

```
BEARING_TRACKER=none            # none | jira | gitlab | github | rest
BEARING_TRACKER_URL=            # base url of the tracker
BEARING_TRACKER_PROJECT=        # Jira project key | group/repo | owner/repo | REST tracker project key
BEARING_TRACKER_EMAIL=          # Jira or REST tracker login email
BEARING_TRACKER_TOKEN=          # Jira API token, GitLab or GitHub token (or rely on glab / gh auth), REST bearer token
BEARING_TRACKER_PASSWORD=       # REST tracker password, when no token is set
BEARING_TRACKER_DONE_STATUS=Done  # the status "close" moves a ticket to
BEARING_TRACKER_MAX_PAGES=20    # the most pages "list" follows before it stops and says so
BEARING_TASK_ID_PREFIX=         # optional: force the id prefix in branch names, e.g. PROJ, GH, GL
BEARING_GIT_HOST=both           # gitlab | github | both: which CI and change template a repository gets
BEARING_KIT_REMOTE=             # git url of the Bearing fork developers install from
BEARING_ORG_ID=com.example      # reverse-domain id for mobile bundle ids
```

`BEARING_GIT_HOST` is not a tracker setting but lives in the same file; the
full key table with defaults is in [INSTALL.md](INSTALL.md) and the
handbook's configuration reference.

Format: `KEY=value`, one per line; `#` starts a comment; a value with
spaces or a `#` goes in double quotes. The same file feeds repository
creation: `plugins/bearing/bin/brg-scaffold` and `plugins/bearing/bin/brg-adopt` read it before computing
their defaults, so `BEARING_KIT_REMOTE` becomes the default `--kit-remote`
(falling back to the kit's own git remote, then `file://<kit>`),
`BEARING_ORG_ID` the default `--org` (falling back to `com.example`) and
`BEARING_TASK_ID_PREFIX` the default `--tracker` (no prefix when it is unset,
so branches carry any `[A-Z][A-Z0-9]*-<n>` id or `NOTASK-<n>`).
Explicit flags always win.

`plugins/bearing/bin/brg-tracker config` prints the effective tracker, where the value
came from (environment, the file, or the default), url, project, email,
whether a token or password is set, the adapter and the id prefix. It
never prints a token or password.

## Key shapes

| Tracker | Key | Example | Branch |
| --- | --- | --- | --- |
| none | any `[A-Z][A-Z0-9]*(-[0-9]+)+` | `TASK-142`, `NOTASK-3` | `feature/TASK-142-LoginLockout` |
| jira | `<project>-N` | `PROJ-142` | `feature/PROJ-142-LoginLockout` |
| gitlab | `GL-<iid>` | `GL-42` | `feature/GL-42-LoginLockout` |
| github | `GH-<number>` | `GH-9` | `feature/GH-9-LoginLockout` |
| rest | whatever the server returns in `key` | `PP-17` | `feature/PP-17-LoginLockout` |

The git hooks accept every shape above through one pattern
(`TASK_ID_RE` in `.githooks/lib.sh`); a REST tracker whose keys do not
match it still works for tickets, and branches then carry a
`BEARING_TASK_ID_PREFIX` id or `NOTASK-<n>`. `BEARING_TASK_ID_PREFIX` narrows what
`start-task` accepts; `resolve <KEY>` turns a key into the id the tracker's
API takes.

## The command surface

```
brg-tracker config | me | get <KEY> | resolve <KEY>
brg-tracker list [--type t] [--status s] [--q text]
brg-tracker create --type <epic|story|task|bug|testcase> --title <s> [--description-file f] [--parent KEY] [--priority p]
brg-tracker update <KEY> [--status name] [--assignee me|email|login] [--title s] [--description-file f]
brg-tracker comment <KEY> (<text> | --file f)
brg-tracker link <KEY> <relates|blocks> <KEY2>
brg-tracker trace <KEY> [--branch b] [--mr url] [--commits a,b] [--tests KEY,..] [--adr ADR-nnnn]
```

Every script uses `set -euo pipefail` and `curl -sS`, prints one line per
action, exits non-zero with a one-line reason (an unreachable host is
`cannot reach <url>: <curl's line>`, never a stack of curl noise), and
answers `--help`. Exit codes: 0 done, 1 failed, 2 usage, 3 skipped
because the tracker is `none` (write commands only).

## The `none` mode

`BEARING_TRACKER=none` (or an absent file) means the workflow runs without a
tracker. Every command prints
`tracker: none (set BEARING_TRACKER in ~/.config/bearing/bearing.env)`; read
commands (`me`, `get`, `list`, `resolve`, `config`) exit 0 and write
commands (`create`, `update`, `comment`, `link`, `trace`) exit 3 so a
caller can treat the step as skipped. `start-task` still creates the branch
from a user-chosen id or `NOTASK-<n>`; `merge-request` and `traceability`
report `tracker: none` rather than a gap; `tracker-sync` skips every
ticket step with a note. Nothing asks for credentials.

## Adapters

### Jira Cloud (`plugins/bearing/bin/brg-jira`)

- Config: `BEARING_TRACKER_URL=https://you.atlassian.net`,
  `BEARING_TRACKER_PROJECT` (project key), `BEARING_TRACKER_EMAIL`,
  `BEARING_TRACKER_TOKEN` (an API token from id.atlassian.com). Basic auth;
  the credentials reach curl through a config pipe, never the command
  line.
- Issue types: `epic=Epic,story=Story,task=Task,bug=Bug,testcase=Test`
  by default; override any entry with
  `BEARING_JIRA_TYPES="testcase=Xray Test,bug=Defect"`. `brg-jira types`
  prints the effective map.
- `create --parent` sets the Jira parent (story under epic, subtask
  under story, test under story where the site allows it). `--priority`
  is capitalised to the Jira default names.
- `update --status` lists the transitions available now and matches the
  name (or the target status) case-insensitively; an unknown name stops
  with the list. `--assignee me|email|accountId` resolves the account id
  from the email. Descriptions and comments are sent as Atlassian
  Document Format (`### ` headings, `- ` bullets, paragraphs).
- `link` creates a `Relates` or `Blocks` issue link. `trace` posts the
  comment and links any Jira keys named in `--tests`. `list` uses JQL
  through the `search/jql` endpoint. Extra: `transitions <KEY>`,
  `close <KEY>` (transition to Done).

### GitLab issues (`plugins/bearing/bin/brg-gitlab`)

- Config: `BEARING_TRACKER_URL` (default `https://gitlab.com`),
  `BEARING_TRACKER_PROJECT=group/repo`, `BEARING_TRACKER_TOKEN` (personal token,
  scope `api`). With no token the adapter uses `glab api` when `glab` is
  installed and authenticated; with neither it stops and says so.
- Type and status are scoped labels: `type::story`, `status::in-review`
  (`--status "In Review"` is slugged), `priority::high`. A status of
  `done` or `closed` also closes the issue; any other status reopens a
  closed one. `list` filters by those labels; `--q` is GitLab's search.
- `create --parent` writes a `Parent: #N` line and adds a `relates_to`
  link. `link` creates an issue link (`relates_to` or `blocks`).
  `comment` and `trace` are notes. `--assignee me|login|email` (email
  search needs the token's user to be allowed to search by email).
- Extra: `close <KEY>`.

### GitHub issues (`plugins/bearing/bin/brg-github`)

- Config: `BEARING_TRACKER_URL` (default `https://github.com`; a GitHub
  Enterprise host uses `<url>/api/v3`), `BEARING_TRACKER_PROJECT=owner/repo`,
  `BEARING_TRACKER_TOKEN` (scope `repo`). With no token the adapter uses
  `gh api` when `gh` is installed and authenticated.
- Type, status and priority are plain labels (`type:story`,
  `status:in-review`, `priority:high`) created on first use with a
  colour per kind. A status of `done` or `closed` also closes the issue.
  Pull requests are filtered out of `list`; `--q` goes through the search
  API.
- GitHub has no issue links: `link` posts a pair of cross-reference
  comments (`Relates to #N`, or `Blocks #N` and `Blocked by #M`) and
  `--parent` writes a `Parent: #N` line. `comment` and `trace` are issue
  comments. `--assignee me|login|email` (email search is best effort).
- Extra: `close <KEY>`.

### REST tracker (`plugins/bearing/bin/brg-rest`)

- Config: `BEARING_TRACKER=rest`, `BEARING_TRACKER_URL` (the server's base
  url, required), `BEARING_TRACKER_PROJECT` (project key), and either a
  bearer token in `BEARING_TRACKER_TOKEN` or `BEARING_TRACKER_EMAIL` plus
  `BEARING_TRACKER_PASSWORD` for the login endpoint. Configuration comes
  only from the environment and `bearing.env`;
  `docs/examples/rest-tracker.env.example` shows the keys. A token from a
  login is cached at `~/.config/bearing/rest.token` (mode 600); on a 401
  the client logs in again once when a password is set. An account that
  answers the login with `mfa_required` needs `BEARING_TRACKER_MFA_CODE`
  exported for that one call.
- Credentials reach curl through a config file on a pipe and request
  bodies through stdin, never on the command line, and are never printed.
  Every call has a 30 s budget. A 429 is retried once after 2 s; a 5xx is
  retried once for GET and PUT; a create or a comment answered 5xx is
  sent again only after a search for the random marker it carries (an
  HTML comment at the end of its text) finds nothing, so a retry never
  duplicates. `list` follows limit/offset pages up to
  `BEARING_TRACKER_MAX_PAGES` (default 20), says when it stops early and
  prints the count on stderr.
- Keys: a key is whatever the server returns in an issue's `key` field;
  the client assumes no shape. Every issue path takes the numeric `id`,
  so a key is resolved through the search endpoint, then, when that finds
  nothing and `BEARING_TRACKER_PROJECT` is set, through the project's
  issue list. A bare number is taken as an id.
- `brg-tracker create --parent` maps to a field by type (story:
  `epic_id`, bug: `story_id`, everything else: `parent_id`). Types:
  `epic, story, task, bug, subtask, testscenario, testcase`. Priority:
  `lowest, low, medium, high, highest`; an unknown type or priority is
  rejected by the client before the call.
- Statuses are the server's, per project and per type; `brg-rest statuses
  <project> <type>` lists them and `update --status` matches a name
  case-insensitively. `BEARING_TRACKER_DONE_STATUS` (default `Done`) is
  what `close` moves to.
- `link` supports `relates` and `blocks` on the surface (the client also
  knows `blocked_by` and `duplicates`). `trace` posts a structured
  comment and adds a `relates` link to every `--tests` id the server
  resolves as an issue.
- `plugins/bearing/bin/brg-rest` subcommands, for the engineer when the generic surface
  is not enough (labels, points, due dates, statuses):

  ```
  brg-rest login | me | projects | statuses <project> [type]
  brg-rest resolve <KEY|id>                 -> numeric id
  brg-rest get <KEY|id>                     -> the issue JSON
  brg-rest list <project> [--type t] [--status name] [--q text] [--limit n]
  brg-rest create <project> --type <t> --title <s> [--description-file f]
         [--priority p] [--epic KEY] [--parent KEY] [--story KEY]
         [--labels a,b] [--points n] [--assignee me|email]
  brg-rest update <KEY|id> [--status name] [--assignee me|email] [--title s]
         [--description-file f] [--priority p] [--points n] [--due YYYY-MM-DD]
  brg-rest close <KEY|id>
  brg-rest comment <KEY|id> (<text> | --file f)
  brg-rest link <KEY|id> <blocks|blocked_by|relates|duplicates> <KEY|id>
  brg-rest trace <KEY|id> [--branch b] [--mr url] [--commits a,b] [--tests KEY,..]
         [--adr ADR-nnnn] [--docs path,..]
  ```

## REST tracker protocol

What a server must answer for `BEARING_TRACKER=rest`. Paths are relative
to `BEARING_TRACKER_URL`. Requests with a body send
`Content-Type: application/json`; every request sends
`Accept: application/json` and, except the two login calls,
`Authorization: Bearer <token>`. Responses are JSON. The client reads only
the fields named here and ignores any others, so a server may return
more. `{project}` is a project key (`BEARING_TRACKER_PROJECT`); `{id}` is
an issue's numeric id.

Status codes: any 2xx is success; 401 triggers one fresh login when a
password is configured, then fails; 403 fails with a credentials hint;
429 is retried once; a 5xx is retried as described above; any other
code fails and the client prints the response's `error` field (or the
body) in one line. An error body is `{"error": "<message>"}`.

### Authentication

A token set in `BEARING_TRACKER_TOKEN` is sent as is and no login is
made. Without one, the client logs in:

| Method | Path | Request | Response |
| --- | --- | --- | --- |
| POST | `/api/auth/login` | `{"email", "password"}` | `{"token"}`, or `{"mfa_required": true, "mfa_token"}` |
| POST | `/api/auth/mfa` | `{"mfa_token", "code"}` | `{"token"}` (only when the login asked for it) |

A failed login answers any non-2xx with `{"error"}`. The token is opaque
to the client and cached until a 401.

### Endpoints

| Method | Path | Request | Response |
| --- | --- | --- | --- |
| GET | `/api/auth/me` | | `{"id", "name", "email"}` |
| GET | `/api/projects` | | `[{"id", "key", "name"}]` |
| GET | `/api/projects/{project}/statuses` | | `[{"id", "type", "name", "category"}]`, one per status per issue type |
| GET | `/api/projects/{project}/members` | | `[{"email" or "user": {"email"}, "user_id" or "id"}]` |
| GET | `/api/projects/{project}/labels` | | `[{"id", "name"}]` |
| GET | `/api/projects/{project}/issues` | query: `type`, `status` (a name), `q` (text), `reporter=me`, `limit`, `offset` | an array of issues; optional `X-Total-Count` header |
| POST | `/api/projects/{project}/issues` | `{"type", "title", "description"}` plus optional `priority`, `epic_id`, `parent_id`, `story_id`, `story_points`, `assignee_id`, `label_ids` | the created issue |
| GET | `/api/issues/{id}` | | `{"issue": <issue>, "comments": [{"id", "body", ...}]}` |
| PUT | `/api/issues/{id}` | any of `status_id`, `assignee_id`, `title`, `description`, `priority`, `story_points`, `due_date` (`YYYY-MM-DD`) | the updated issue |
| POST | `/api/issues/{id}/comments` | `{"body"}` (markdown) | `{"id", "issue_id", "created_at"}` |
| POST | `/api/issues/{id}/links` | `{"type", "target_id"}`, type one of `relates`, `blocks`, `blocked_by`, `duplicates` | any 2xx body |
| GET | `/api/search?q={key}` | | any JSON; the client takes the `id` of the first object anywhere in it whose `key` equals the query |

An issue object carries `id` (number), `key` (string, the key people use),
`type`, `title`, `description`, `project_id` (the `id` of its project in
`/api/projects`), `status_name`, `priority` and `assignee` (`{"name"}` or
null). The list endpoint may leave `description` out.

Rules the client relies on:

- Paging: the list endpoint honours `limit` and `offset`. The client asks
  for 200 a page and stops at a short page, or at `X-Total-Count` when
  the header is present.
- `reporter=me` limits the list to issues the caller created; the client
  uses it, with `type`, to look for a create that a 5xx may have applied.
- Idempotent retry: the server stores `description` and comment `body`
  verbatim, so the marker comment the client appends can be found again
  through `GET /api/issues/{id}`.
- Search: `/api/search` must find an issue by its exact key. When it
  cannot, the client falls back to paging the project's issue list for
  the key, which needs `BEARING_TRACKER_PROJECT`.

## Testing without a live tracker

`bash -n` and shellcheck run on every script in `make check`. With a fake
host (`BEARING_TRACKER=jira BEARING_TRACKER_URL=https://jira.invalid ...`) each
adapter fails at the first network call with one line; with
`BEARING_TRACKER=none` every command prints the none line and exits 0 or 3;
`brg-tracker config` shows what any mode resolved to.
