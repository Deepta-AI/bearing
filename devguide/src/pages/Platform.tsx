import { Terminal } from "../components/Terminal";
import { Code, Defs, H2, Note, Page, S } from "../components/ui";
import { data } from "../lib/data";

const VERBS: [string, string, string, string, string][] = [
  ["me", "GET /api/auth/me", "GET /rest/api/3/myself", "GET /user", "GET /user"],
  ["get / resolve", "search, then the issue", "the issue by key", "the issue by iid", "the issue by number"],
  ["list", "paged, type and status filters", "JQL via search/jql", "label filters, Link header paging", "label filters, PRs dropped"],
  ["create", "POST issue; epic_id or story_id for --parent", "POST issue; parent field", "POST issue; type:: label; Parent: line", "POST issue; type: label; Parent: line"],
  ["update --status", "status id for the name", "the matching transition", "status:: label; done closes", "status: label; done closes"],
  ["comment, trace", "a comment", "an ADF comment", "a note", "an issue comment"],
  ["link", "an issue link", "a Relates or Blocks link", "relates_to or blocks link", "cross-reference comments"],
];

export function Trackers() {
  return (
    <Page
      title="Trackers"
      lede="Skills never call a tracker's API. They call plugins/bearing/bin/brg-tracker with one of eleven verbs, and it hands the call to one adapter chosen by BEARING_TRACKER. Adding a tracker means one new script, not a change to any skill."
      toc={[
        { id: "shape", label: "The shape" },
        { id: "verbs", label: "Verbs and adapters" },
        { id: "keys", label: "Key shapes" },
        { id: "none", label: "Tracker none" },
        { id: "safety", label: "Credentials and retries" },
        { id: "tested", label: "Tested against fakes" },
      ]}
      sources={["plugins/bearing/bin/brg-tracker", "plugins/bearing/bin/brg-jira", "plugins/bearing/bin/brg-gitlab", "plugins/bearing/bin/brg-github", "plugins/bearing/bin/brg-rest", "docs/TRACKERS.md", "tests/contract/fake_tracker.py"]}
    >
      <H2 id="shape">The shape</H2>
      <div className="fanout wide">
        <div className="fo-src">
          <b>Skills</b>
          <span>
            <S name="start-task" />, <S name="backlog" />, <S name="merge-request" />, <S name="traceability" />, <S name="tracker-sync" />
          </span>
        </div>
        <div className="fo-mid">
          <S name="brg-tracker" />
          <span>reads BEARING_TRACKER, routes the verb</span>
        </div>
        <div className="fo-outs">
          {["brg-jira", "brg-gitlab", "brg-github", "brg-rest", "none: exit 3 on writes"].map((a) => (
            <div key={a} className="fo-out">
              {a.startsWith("none") ? a : <S name={a} />}
            </div>
          ))}
        </div>
      </div>
      <Terminal id="tracker" height={170} />

      <H2 id="verbs">Verbs and adapters</H2>
      <div className="tablewrap">
        <table>
          <thead>
            <tr>
              <th>Verb</th>
              <th>REST tracker</th>
              <th>Jira Cloud</th>
              <th>GitLab issues</th>
              <th>GitHub issues</th>
            </tr>
          </thead>
          <tbody>
            {VERBS.map((r) => (
              <tr key={r[0]}>
                {r.map((c, i) => (
                  <td key={i}>{i === 0 ? <code>{c}</code> : c}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p>
        Plus <code>config</code> (shared, never prints a secret) and <code>close</code> (status <code>BEARING_TRACKER_DONE_STATUS</code>, default Done).{" "}
        <code>trace</code> posts a structured comment with the branch, MR, commits, test case ids and ADRs, because no tracker has git fields; that comment and
        the links are the traceability.
      </p>

      <H2 id="keys">Key shapes</H2>
      <Defs
        rows={[
          ["none", "any [A-Z][A-Z0-9]*(-[0-9]+)+, such as TASK-142 or NOTASK-3"],
          ["jira", "PROJ-142"],
          ["gitlab", "GL-42 (the issue iid)"],
          ["github", "GH-9 (the issue number)"],
          ["rest", "whatever key the server returns, such as PP-17"],
        ]}
      />
      <p>
        Every shape matches one regex, <code>TASK_ID_RE</code> in <code>.githooks/lib.sh</code>, so the git hooks, the guard's task-id hint and the branch
        convention agree whatever the tracker. A REST tracker's keys are its server's own; the adapter resolves them through the protocol's search
        endpoint and assumes no shape.
      </p>

      <H2 id="none">Tracker none</H2>
      <p>
        No tracker is a supported mode, not an error. Read verbs exit 0, write verbs print{" "}
        <code>tracker: none (set BEARING_TRACKER in ~/.config/bearing/bearing.env)</code> and exit 3, and every calling skill treats 3 as "skipped". Nothing
        asks for credentials.
      </p>

      <H2 id="safety">Credentials and retries</H2>
      <ul>
        <li>Credentials come from the env file, which is mode 600, outside every repository, and denied to the sandbox. They reach curl through a config on a pipe, never the command line, so they never appear in a process list.</li>
        <li>The env file is parsed line by line, never sourced, so a value cannot run code. An environment variable always wins over the file.</li>
        <li>GET and PUT retry on 429 and 5xx. A POST retries only after checking whether the first attempt landed, by looking for a marker it wrote (an HTML comment or an entity property), so a retry never creates a duplicate.</li>
        <li>Listing follows pages up to <code>BEARING_TRACKER_MAX_PAGES</code> (default 20) and prints the count on stderr.</li>
      </ul>

      <H2 id="tested">Tested against fakes</H2>
      <p>
        <code>tests/contract/tracker_fake_server.sh</code> starts <code>fake_tracker.py</code>, a local server that speaks all four APIs, and runs every adapter
        against it: the recorded run made 68 commands and 71 requests, with idempotent retry, pagination and quoted-token cases for each adapter and a slow
        call, in 21 cases and 328 assertions. No live tracker is ever touched by the tests.
      </p>
    </Page>
  );
}

export function Harnesses() {
  const h = data.scripts.find((s) => s.name === "brg-harness")!;
  return (
    <Page
      title="Other harnesses"
      lede="The standard lives in AGENTS.md, the gate in the Makefile, the guard in one script. brg-harness carries all three to nine other coding harnesses, each through the mechanism that harness actually offers."
      toc={[
        { id: "idea", label: "One guard, many adapters" },
        { id: "matrix", label: "What each harness gets" },
        { id: "vendored", label: "The vendored guard" },
        { id: "honest", label: "What is and is not enforced" },
      ]}
      sources={["plugins/bearing/bin/brg-harness", "plugins/bearing/skills/harness-setup/references/harness-matrix.md", "tests/integration/harness_each.sh"]}
    >
      <H2 id="idea">One guard, many adapters</H2>
      <p>
        Most harnesses have some way to run a script before a shell command, but each passes a different JSON and expects a different answer. So the decision
        stays in <code>brg-guard</code> and each harness gets a small adapter that translates: Cursor wants{" "}
        <code>{'{"permission": "deny", "user_message": ...}'}</code>, Copilot wants <code>permissionDecision</code>, Cline wants <code>{'{"cancel": true}'}</code>
        , Windsurf reads the exit code. <S name="brg-harness" /> ({h.lines.toLocaleString("en")} lines) writes them.
      </p>

      <H2 id="matrix">What each harness gets</H2>
      <div className="tablewrap">
        <table>
          <thead>
            <tr>
              <th>Harness</th>
              <th>Files written</th>
              <th>Before a shell command</th>
            </tr>
          </thead>
          <tbody>
            <tr><td>Cursor</td><td><code>.cursor/hooks.json</code>, <code>.cursor/rules/*.mdc</code></td><td>beforeShellExecution adapter</td></tr>
            <tr><td>Codex</td><td><code>.codex/hooks.json</code>, <code>.codex/rules/bearing.rules</code></td><td>PreToolUse adapter, plus execpolicy prefixes</td></tr>
            <tr><td>Gemini CLI</td><td><code>.gemini/settings.json</code>, <code>GEMINI.md</code></td><td>BeforeTool adapter, plus tools.exclude</td></tr>
            <tr><td>Copilot</td><td><code>.github/hooks/bearing.json</code>, instructions</td><td>preToolUse adapter</td></tr>
            <tr><td>OpenCode</td><td><code>.opencode/plugins/brg-guard.js</code>, <code>opencode.json</code></td><td>a JS plugin calling the guard</td></tr>
            <tr><td>Windsurf</td><td><code>.devin/hooks.json</code>, <code>.devin/rules/</code></td><td>pre_run_command adapter</td></tr>
            <tr><td>Cline</td><td><code>.clinerules/hooks/PreToolUse</code>, rules</td><td>PreToolUse hook</td></tr>
            <tr><td>Zed</td><td><code>.zed/settings.json</code>, <code>.rules</code></td><td>always_deny regexes only (Zed has no agent hooks)</td></tr>
            <tr><td>Kiro</td><td><code>.kiro/hooks/brg-guard.json</code>, steering</td><td>PreToolUse adapter</td></tr>
          </tbody>
        </table>
      </div>
      <p>
        Every command policy (execpolicy, tools.exclude, always_deny, the OpenCode permissions, the Kiro and Copilot lists) is derived from{" "}
        <code>brg-guard --verbs</code>, so the table is written once. With <code>--kit-url</code>, the Bearing skills are installed for the harness with{" "}
        <code>npx skills add</code>. A file that exists with different content is left alone and the proposal goes to <code>&lt;file&gt;.bearing-new</code>,
        as with adopt.
      </p>

      <H2 id="vendored">The vendored guard</H2>
      <p>
        On other harnesses the plugin is not installed, so the guard is copied into the repository as <code>.bearing/bin/brg-guard</code> with the kit version
        stamped in place of <code>__VERSION__</code>. Hooks then work wherever the kit lives, or without it. <S name="brg-doctor" /> compares the stamp with the
        kit and reports a stale copy.
      </p>

      <H2 id="honest">What is and is not enforced</H2>
      <Note title="Prefix rules are advice; the hook is the control">
        <p>
          A prefix policy such as Codex's execpolicy or Zed's regexes sees <code>env git push</code> as a command starting with <code>env</code>. Only the hook
          over the guard strips wrappers. Where a harness has no hook (Zed), Bearing says so rather than pretending. The per-harness truth is in{" "}
          <code>plugins/bearing/skills/harness-setup/references/harness-matrix.md</code>, and the Codex and Cursor adapters are marked unverified until run against the real tools.
        </p>
      </Note>
    </Page>
  );
}

export function Install() {
  return (
    <Page
      title="Install, doctor, packs"
      lede="install.sh puts the plugin, the packs and one config file on a machine; brg-doctor proves what is there; brg-install-packs brings in the third-party skills the workflow names as main choices, each pinned."
      toc={[
        { id: "paths", label: "Plugin only or full install" },
        { id: "profiles", label: "Profiles" },
        { id: "steps", label: "What install.sh does" },
        { id: "env", label: "bearing.env" },
        { id: "doctor", label: "brg-doctor" },
        { id: "packs", label: "Third-party packs" },
        { id: "uninstall", label: "Uninstall" },
      ]}
      sources={["install.sh", "plugins/bearing/bin/brg-doctor", "plugins/bearing/bin/brg-install-packs", "plugins/bearing/bin/pinned-packs.txt", "plugins/bearing/templates/user/bearing.env", "docs/INSTALL.md"]}
    >
      <H2 id="paths">Plugin only or full install</H2>
      <p>
        <code>/plugin marketplace add Deepta-AI/bearing</code> then <code>/plugin install bearing@bearing</code> inside Claude Code gives the whole plugin: the
        skills, the agents, <code>plugins/bearing/hooks/hooks.json</code> and the <code>bin/</code> scripts the hooks and skills call, from Claude Code's cache. What only{" "}
        <code>install.sh</code> adds: <code>bearing.env</code>, the personal <code>CLAUDE.md</code>, the packs for the profile, the doctor run, and a checkout
        at <code>~/bearing</code> that <code>--no-claude</code> and other harnesses work from. Without an env file every script falls back to its defaults,
        so the tracker is <code>none</code>.
      </p>

      <H2 id="profiles">Profiles</H2>
      <Defs
        rows={[
          ["minimal", "the Bearing plugin, bearing.env, the personal CLAUDE.md if absent, then the doctor"],
          ["standard", "minimal plus Superpowers, gstack and GSD Core; the default"],
          ["full", "standard plus brg-install-packs: every open-source skill a stage names as its main choice"],
        ]}
      />
      <p>
        The chosen profile is written to <code>BEARING_PROFILE</code>, and the doctor reads it: on a minimal machine, Superpowers and gstack are optional
        rather than missing.
      </p>

      <H2 id="steps">What install.sh does</H2>
      <ol className="steps">
        <li>
          <strong>Prerequisites.</strong> git and (unless <code>--no-claude</code>) the claude CLI are required; node for the standard profile, found through
          nvm, fnm or Volta if not on PATH; jq, make and python3 warned about when missing.
        </li>
        <li>
          <strong>The kit.</strong> The <code>bearing</code> marketplace is added (the checkout, or <code>--remote</code>) and <code>bearing@bearing</code> is
          installed or updated. With <code>--no-claude</code> there is no plugin step; the checkout is refreshed with <code>pull --ff-only</code> instead.
        </li>
        <li>
          <strong>Packs.</strong> Superpowers from the official marketplace, gstack cloned and set up, GSD Core through npx; on full, brg-install-packs.
        </li>
        <li>
          <strong>Configuration.</strong> <code>~/.config/bearing/bearing.env</code> from <code>plugins/bearing/templates/user/bearing.env</code> with mode 600 and never
          overwritten. The personal <code>~/.claude/CLAUDE.md</code>{" "}
          only if absent.
        </li>
        <li>
          <strong>The doctor</strong>, and one last line: <code>install.sh: N installed, M already present, K skipped, F failed</code>. Exit 1 when anything
          failed. <code>--dry-run</code> prints every action and touches nothing, which <code>tests/unit/install_dry_run.sh</code> proves against a fake HOME.
        </li>
      </ol>
      <Note title="Updating an installed copy">
        <p>
          Claude Code caches a plugin under its version, and an update to the same version keeps the old copy. Bump <code>VERSION</code> for a release, or run{" "}
          <code>claude plugin uninstall bearing@bearing</code> then install again while developing.
        </p>
      </Note>

      <H2 id="env">bearing.env</H2>
      <p>One file per developer, the only place anything about your organisation, the git host or the tracker lives.</p>
      <Code cap="~/.config/bearing/bearing.env (the keys; see docs/INSTALL.md)">{`BEARING_TRACKER=none            # none | jira | gitlab | github | rest
BEARING_PROFILE=standard        # written by install.sh
BEARING_GIT_HOST=both           # gitlab | github | both: which CI and templates repos get
BEARING_TASK_ID_PREFIX=         # narrows what start-task accepts
BEARING_TRACKER_URL=
BEARING_TRACKER_PROJECT=
BEARING_TRACKER_EMAIL=
BEARING_TRACKER_TOKEN=
BEARING_TRACKER_DONE_STATUS=Done
BEARING_TRACKER_MAX_PAGES=20
BEARING_KIT_REMOTE=             # a fork's git url; install, scaffold and adopt read it
BEARING_ORG_ID=com.example      # reverse domain for mobile ids`}</Code>
      <p>
        Every script reads it with the same parser, and <code>tests/unit/load_env.sh</code> compares the seven copies of that parser so they cannot drift.{" "}
        <code>BEARING_ENV</code> points at a different file, which is how the tests and the recordings on this site run with a tracker of none.
      </p>

      <H2 id="doctor">brg-doctor</H2>
      <p>
        One line per check (<code>ok</code>, <code>MISSING</code>, <code>optional</code>, <code>skipped</code>) and a summary{" "}
        <code>brg-doctor: N checks, M missing, K optional</code>. On the machine: the claude CLI, the plugin, the packs by profile, the env file and its mode,
        the personal CLAUDE.md, git, make, jq, python3, bash, and the sandbox prerequisites (bubblewrap and socat on Linux). Inside a repository: AGENTS.md,
        the CLAUDE.md import on line one, no unfilled placeholder, settings, rules, core.hooksPath (or a directory whose hooks chain to .githooks), the three
        hooks, a check target, CI and a change template for either host, <code>.bearing/state</code> ignored, and a vendored guard of the current version.{" "}
        <code>tests/integration/doctor_matrix.sh</code> runs it over seven repository states and three profiles.
      </p>

      <H2 id="packs">Third-party packs</H2>
      <p>
        <S name="brg-install-packs" /> installs from four sources, each idempotently and each reported as installed, present, skipped or FAILED:
      </p>
      <ol className="steps">
        <li>
          <strong>The official marketplace</strong>: plugins through <code>claude plugin install</code>.
        </li>
        <li>
          <strong>The skills CLI</strong>: <code>npx skills add &lt;repo&gt; --skill &lt;name&gt; -a claude-code -g -y</code>, one row per skill.
        </li>
        <li>
          <strong>Playwright</strong>: <code>npx @playwright/cli install --skills -g</code>.
        </li>
        <li>
          <strong>Pinned packs</strong>: <code>plugins/bearing/bin/pinned-packs.txt</code> rows of <code>kind|repo|commit|path|name|licence</code>, fetched at that exact
          commit into <code>~/.cache/bearing-packs</code> and copied to <code>~/.claude/skills/&lt;name&gt;</code> with a <code>.bearing-pack</code> provenance
          file, so a skill installed by someone else is never overwritten.
        </li>
      </ol>
      <Note title="Moving a pin">
        <p>Every pinned SKILL.md was read at its commit before it was listed. Moving a commit means reading the skill again at the new commit; that is the review, not a formality.</p>
      </Note>

      <H2 id="uninstall">Uninstall</H2>
      <p>
        <code>install.sh --uninstall</code> removes the plugin and the marketplace, asks before removing the env file, removes <code>~/.claude/CLAUDE.md</code>{" "}
        only while it is still the untouched template, and prints how to unhook each repository. It never edits a repository.
      </p>
    </Page>
  );
}
