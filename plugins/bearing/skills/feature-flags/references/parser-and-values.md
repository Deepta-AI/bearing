# feature-flags: reading the parser and mapping effective values

Read when you run steps 2 and 3: how a value becomes on, and what every environment resolves to.

2. **Read how a value becomes "on".** Open the module and answer, with
   the line: which sources feed it (environment, per-region files,
   per-account or per-tenant overrides, remote config), in what order,
   and how a string becomes a boolean. Test the parser against what the
   deploy config actually contains: `"false"`, `"0"`, `"off"` and `""`
   must be off. A parser that treats any non-empty value as on (Go
   `!= ""`, Python truthiness, JS `!!process.env.X`) turns every
   `FLAG_X=false` into on. That is a finding with a live consequence:
   name each deployed setting whose meaning is inverted and what is
   running in production today because of it. Fixing the parser changes
   production, so either fix it with a test for `"false"` and state which
   flags switch off in which environment on deploy, or leave it and
   recommend the fix; never fix it silently.
3. **Map the effective value everywhere.** List the environments from the
   deploy directory and manifests, not from the `values:` lines: a region
   or workload that never mentions the flag runs the default, and it is
   the one people forget. Include values that arrive indirectly: `envFrom`
   ConfigMaps and Secrets, shared env files, base images, Helm values (in
   Kubernetes an explicit `env` entry wins over `envFrom` for the same
   name). Then write the value each deployed environment and each
   overridden account resolves to, under the parser from step 2. Every
   separate process loads flags itself: a CronJob, worker or second binary
   has its own env list and its own `main`. Example and template files
   are not environments.

1. **Audit before touching anything.** Run
`python3 "${CLAUDE_PLUGIN_ROOT}/skills/feature-flags/scripts/flags_check.py"`
(`--module <path>` for a module elsewhere). Keep its output: the
`problem:` lines are the state you found, the `values:` lines show
every `FLAG_` setting per file and line (and the deployed files that
leave it unset), `config names:` lines are config files naming a flag
(override maps, remote-config defaults), and `client read:` lines are
the places the browser reads a flag by key. A `reads as ON` problem is
the parser trap of step 2, already found.

The hard part is never the `if`. It is knowing every place the feature reaches,
what value each environment really resolves to, and whether a change to the
flag changes production. Most of this skill is those three checks.
