# feature-flags: adding a flag and gating its exposure

Read when you run add (step 4) or find the exposures of a branch (step 5).

4. **Check the name is free before using it.** Grep every config source
   from step 3 for `FLAG_<NAME>`: a shared ConfigMap or env file another
   team owns may already set it, and a workload that loads it turns the
   new flag on at merge (under a lenient parser even `off` does). Pick a
   name nothing sets, or override it to off in your own workloads; never
   edit another team's shared config to make room. Then: snake_case name, one typed constant in the module
   (`flags.CSVExport`, `Flag.NEW_CHECKOUT`), included wherever the module
   lists flags to load, default off. One register row in the register's
   own columns: owner rotation, removal task, target date, what "on"
   means for a user. Target date: the team's limit counted from today,
   inclusive, else 90 days:
   `date -v+90d +%F 2>/dev/null || date -d "+90 days" +%F`.
   `--kill-switch` creates `kill_<path>`: on means the path returns its
   safe fallback, named in the row. Add `FLAG_<NAME>` to `.env.example`
   with the off value. Add it nowhere else: every environment stays off
   by omission.

5. **Find every exposure from the diff, not from one function.** Run
   `git diff <base>...HEAD` and list what this branch adds that a user,
   customer or another system can reach: routes, links or URLs to the
   feature inside other responses, emails and pages, attachments,
   notifications, jobs and other binaries, client payloads, public API
   specs. Grep the route path and the feature's user-visible strings as
   well as its entry function; a link to the new endpoint in an existing
   JSON response or email body is an exposure even though it never calls
   the new code.
