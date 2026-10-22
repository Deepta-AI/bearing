import { Link } from "react-router";
import { Code, Page } from "../components/ui";
import { data } from "../lib/data";

export function GetStarted() {
  return (
    <Page
      crumb="Get started"
      title="Get started"
      lede="Install once per machine. Then put a repository on the standard and start a task. Each step ends with a line to check; if yours differs, Troubleshooting has the fix."
      toc={[
        { id: "plugin", label: "The plugin only" },
        { id: "install", label: "Install on this machine" },
        { id: "repo", label: "Put a repository on the standard" },
        { id: "task", label: "Start a task" },
        { id: "profiles", label: "Install profiles" },
      ]}
    >
      <p>
        Bearing is open source under the MIT licence, at{" "}
        <a href="https://github.com/Deepta-AI/bearing">github.com/Deepta-AI/bearing</a>. Choose one of two ways in: the plugin only, or the full
        install.
      </p>
      <h2 id="plugin">The plugin only</h2>
      <p>Run this inside Claude Code 2.1 or newer:</p>
      <Code>{`/plugin marketplace add Deepta-AI/bearing
/plugin install bearing@bearing`}</Code>
      <p>
        You get the workflow skills, the eight subagents, and the hooks with the guard behind them. Add <code>bearing-backend</code>,{" "}
        <code>bearing-apps</code> or <code>bearing-genai</code> the same way when your repositories need them.
      </p>
      <p>
        The plugin writes no env file, so the tracker stays <code>none</code> until you copy{" "}
        <code>plugins/bearing/templates/user/bearing.env</code> to <code>~/.config/bearing/bearing.env</code>. It installs no companion packs and
        leaves no checkout at <code>~/bearing</code>. For those, use the full install.
      </p>

      <h2 id="install">Install on this machine</h2>
      <p>
        You need a coding harness (Claude Code 2.1 or newer for the plugin), git, Node 22 or newer, make and jq. The full install adds the env file, a
        personal <code>CLAUDE.md</code> starter, the companion packs for the profile, and a doctor run. On a team fork, clone the fork and set{" "}
        <code>BEARING_KIT_REMOTE</code>.
      </p>
      <ol className="steps">
        <li className="stepc">
          <div className="of">1 of 3</div>
          <h3>Clone and install</h3>
          <Code>{`git clone https://github.com/Deepta-AI/bearing ~/bearing
bash ~/bearing/install.sh`}</Code>
          <p>
            Last line: <code>install.sh: N installed, M already present, K skipped, 0 failed</code>
          </p>
        </li>
        <li className="stepc">
          <div className="of">2 of 3</div>
          <h3>Configure</h3>
          <p>
            Edit <code>~/.config/bearing/bearing.env</code>. It sits outside every repository, mode 600. <code>BEARING_TRACKER=none</code> is a valid
            answer.
          </p>
          <Code>{`~/bearing/plugins/bearing/bin/brg-tracker config`}</Code>
          <p>
            First line: <code>tracker: none (from file)</code>, or your tracker's name.
          </p>
        </li>
        <li className="stepc">
          <div className="of">3 of 3</div>
          <h3>Restart and check</h3>
          <p>Plugins load when the harness starts. Restart it, then run this in any repository on the Bearing standard:</p>
          <Code>{`/bearing:doctor`}</Code>
          <p>
            Last line: <code>brg-doctor: N checks, 0 missing, M optional</code>. A <code>MISSING</code> line names its own fix.
          </p>
        </li>
      </ol>

      <h2 id="repo">Put a repository on the standard</h2>
      <p>
        Scaffold a new repository for its stack, or adopt an existing one. Adoption never overwrites a file: each conflict is written beside it as{" "}
        <code>&lt;file&gt;.bearing-new</code>.
      </p>
      <Code>{`/bearing:new-repo go-api InvoiceService       # a new repository
/bearing:onboard-repo --stack react-web      # an existing one`}</Code>
      <p className="muted">
        Stacks: {data.stacks.join(", ")}.
      </p>
      <p>
        <Link to="/files">Default files</Link> lists every file this writes, and the ones on your machine, with their contents and what you may
        change.
      </p>

      <h2 id="task">Start a task</h2>
      <Code>{`/bearing:start-task TASK-142 InvoiceTotals`}</Code>
      <p>
        It creates the branch <code>feature/TASK-142-InvoiceTotals</code> and the state file the next session resumes from. It ends with{" "}
        <code>Next:</code> and the skill to run.
      </p>
      <p>
        From there, follow the <Link to="/flows/feature">feature flow</Link>, or ask <code>/bearing:workflow</code> what comes next. You can also
        say it in plain words ("start task TASK-142"), and Claude loads the matching skill.
      </p>

      <h2 id="profiles">Install profiles</h2>
      <Code>{`bash ~/bearing/install.sh                     # standard: the kit plus Superpowers, gstack, GSD Core and impeccable
bash ~/bearing/install.sh --profile full      # standard plus the other packs the workflow names
bash ~/bearing/install.sh --profile minimal   # the Bearing plugins and the env file, no packs
bash ~/bearing/install.sh --dry-run           # print every action, touch nothing
bash ~/bearing/install.sh --no-claude         # no claude CLI steps, for another harness`}</Code>
      <p>
        The installer is idempotent and never overwrites your env file. Upgrade with <code>/bearing:upgrade-tools</code>. Uninstall with{" "}
        <code>bash ~/bearing/install.sh --uninstall</code>. <code>docs/INSTALL.md</code> lists every option.
      </p>
    </Page>
  );
}

export function Concepts() {
  return (
    <Page
      crumb="Get started"
      title="How skills work"
      lede="A skill is a written procedure the agent follows every time, so nobody types it twice. How skills load explains why dozens can be installed and why some run on their own."
      toc={[
        { id: "anatomy", label: "What is inside a skill" },
        { id: "terms", label: "Terms you will meet" },
        { id: "writing", label: "Writing one" },
      ]}
    >
      <h2 id="anatomy">What is inside a skill</h2>
      <p>
        A skill is a folder with a <code>SKILL.md</code> file. At the start of a session the agent reads only each skill's one-line description. It
        loads the full instructions when a request matches. So the description matters most: it decides whether the skill fires.
      </p>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit,minmax(min(100%,340px),1fr))", gap: "var(--s5)", alignItems: "start" }}>
        <pre style={{ margin: 0 }}>{`merge-request/
├── SKILL.md
│   ---
│   name: merge-request
│   description: Prepare the Merge Request for the
│     current branch ... Use when asked to
│     "prepare the MR", "open a merge request" ...
│   allowed-tools: Read, Bash(make:*), Bash(git diff:*)
│   ---
│   ## Inputs    what it needs, where it looks, the fallback
│   ## Steps     numbered, with counts and stops
│   ## Output contract
│   ## Gotchas   what was learned the hard way
├── scripts/     checks it runs, so counts come from files
├── templates/   files it copies or fills
└── references/  files it reads when a step needs them`}</pre>
        <div className="list" style={{ gridTemplateColumns: "1fr", margin: 0 }}>
          <div>
            <b>Description</b>What it does, then "Use when" and the phrases a developer would say. Too vague and it never fires. Too broad and it fires on everything.
          </div>
          <div>
            <b>Asked for or typed</b>Every Bearing skill loads when your request matches its description. You can also type it as{" "}
            <code>/&lt;plugin&gt;:&lt;name&gt;</code>, such as <code>/bearing:doctor</code>. With many packs installed, Claude Code may list some skills
            by name only. The install guide's "Keep the skill listing lean" section says what to trim.
          </div>
          <div>
            <b>Works alone</b>Every input names a fallback: another place to look, one question, or a minimal version. Another skill is the fuller path, never a prerequisite.
          </div>
          <div>
            <b>Gates print counts</b>A check that examined nothing did not pass. Every check fails on empty input and says how many things it verified.
          </div>
        </div>
      </div>

      <h2 id="terms">Terms you will meet</h2>
      <div className="list">
        <div>
          <b>Slash command</b>A skill you type: <code>/bearing:merge-request</code>, <code>/office-hours</code>. In Claude Code a plugin's skills are
          reachable as <code>/&lt;plugin&gt;:&lt;name&gt;</code>, such as <code>/bearing:doctor</code> or <code>/bearing-backend:go</code>.
        </div>
        <div>
          <b>Subagent</b>A separate agent with a clean context and its own tool limits, named like <code>bearing:reviewer</code>. Bearing ships eight. The
          reviewer, verifier, security auditor, explorer, critic and PRD drafter are read-only. The test writer works in a worktree. The doc writer
          edits only <code>docs/</code> and <code>README.md</code>.
        </div>
        <div>
          <b>Hook</b>A script the harness runs at a set moment: session start, before a shell command, after an edit. Hooks enforce what prose cannot,
          such as refusing the agent's own git push.
        </div>
        <div>
          <b>Plugin</b>How skills, agents and hooks ship together and install in one command. Bearing ships four. Other harnesses take the same skills
          through the skills CLI.
        </div>
        <div>
          <b>AGENTS.md and CLAUDE.md</b>Always-on notes, not skills. AGENTS.md is the standard every agent reads, and CLAUDE.md imports it. Every line
          is paid for on every turn, so both stay short.
        </div>
        <div>
          <b>Rules</b><code>.claude/rules/*.md</code> files with a <code>paths:</code> list load only when a matching file is touched, so stack rules cost nothing until you open that stack's code.
        </div>
      </div>

      <h2 id="writing">Writing one</h2>
      <ol>
        <li>Pick one job you explain again every week. One job per skill.</li>
        <li>Check whether an installed skill already does the job. If one does, use it and pass it your rules.</li>
        <li>
          Run <code>/bearing:new-skill</code>. It scaffolds the folder to the conventions and runs the lints. Then <code>skill-creator</code> runs
          your cases with and without the skill and grades both. A skill that does not beat the run without it is not added.
        </li>
        <li>Add to the Gotchas each time the skill surprises you.</li>
      </ol>
    </Page>
  );
}

export function Config() {
  return (
    <Page
      crumb="Reference"
      title="Configuration"
      lede="One file per machine, never inside a repository: ~/.config/bearing/bearing.env, mode 600, one KEY=value per line. An environment variable of the same name wins over the file, so CI and one-off shells can override it. BEARING_AUTO_PUSH is the exception: it is read from the file only."
      toc={[
        { id: "keys", label: "Every key" },
        { id: "check", label: "Check what resolved" },
      ]}
    >
      <h2 id="keys">Every key</h2>
      <dl className="kv">
        {data.config.map((k) => (
          <div key={k.key} style={{ display: "contents" }}>
            <dt>{k.key}</dt>
            <dd>
              {k.meaning}
              <small>Default: {k.default}</small>
            </dd>
          </div>
        ))}
      </dl>
      <h2 id="check">Check what resolved</h2>
      <p>
        Run <code>brg-tracker config</code>. It shows each value, where it came from, and whether a credential is set. It never prints the
        credential.
      </p>
      <Code>{`tracker: jira (from file)
env file: /home/you/.config/bearing/bearing.env
url: https://you.atlassian.net
project: PROJ
auth: token set
id prefix: PROJ (ids look like PROJ-N)`}</Code>
      <p className="muted">
        With <code>BEARING_TRACKER=none</code>, every ticket write prints <code>tracker: none</code> and exits 3. The skills treat that as skipped,
        never as a failure. <code>docs/TRACKERS.md</code> covers each adapter.
      </p>
    </Page>
  );
}

export function Security() {
  return (
    <Page
      crumb="Reference"
      title="Security model"
      lede="What the kit refuses to do, and what does the refusing. Prose asks; hooks, the guard and git enforce."
    >
      <div className="list rules">
        <div>
          <b>Credentials stay out of repositories and the conversation</b>They live in the env file, mode 600. Tracker adapters pass tokens to curl
          through a config file on a pipe, never on the command line. Repository settings deny reading <code>.env</code> files, keys, keystores and
          cloud credentials.
        </div>
        <div>
          <b>One verb table, fail closed</b>
          <code>plugins/bearing/bin/brg-guard</code> blocks {data.guardVerbs} verbs: push, history rewrites, branch and tag deletion, merges and
          releases on glab and gh, package publishing, image pushes, terraform apply and destroy, and deploy tools. It sees through{" "}
          <code>sudo</code>, <code>env</code>, <code>sh -c</code>, <code>eval</code>, <code>xargs</code> and <code>git -C</code>. It refuses a
          command it cannot read. Every hook and deny list is generated from that one table.
        </div>
        <div>
          <b>Read-only agents</b>The reviewer, verifier, security auditor, explorer, critic and PRD drafter get Read, Grep and Glob only, with no
          shell. The limit is the tool list, not a hook.
        </div>
        <div>
          <b>A push needs a person</b>The pre-push hook asks for the branch name on the terminal, which no agent can type. This holds on every
          harness, with or without hooks.
        </div>
        <div>
          <b>Least-privilege settings</b>
          <code>.claude/settings.json</code> allows read-only tools and make targets. It asks before commits and dependency changes. It denies
          publishing, history rewrites, deployed environments and secrets.
        </div>
        <div>
          <b>Secret scanning</b>The pre-commit hook refuses staged files with token shapes. CI runs the host's secret detection. The{" "}
          <code>secrets</code> skill keeps the inventory and the leak response.
        </div>
      </div>
      <p className="muted">
        Report a weakness in the kit itself privately, through GitHub's vulnerability reporting on{" "}
        <a href="https://github.com/Deepta-AI/bearing/security/advisories/new">Deepta-AI/bearing</a>, as <code>SECURITY.md</code> describes.
      </p>
    </Page>
  );
}

export function Packs() {
  const packs = [
    ["sp", "Superpowers", "Discipline", "brainstorming, writing-plans, executing-plans, test-driven-development, systematic-debugging, verification-before-completion, writing-skills.", "Not used: branch-finishing defaults that push; merge-request covers that step."],
    ["gs", "gstack", "Judgement and live checks", "/office-hours, /plan-ceo-review, /plan-eng-review, /design-consultation, /review, /investigate, /qa, /cso, /design-review, /canary, /retro.", "Denied in repositories on the standard: cookie import, cross-model skills, pair-agent, deploy skills."],
    ["gsd", "GSD Core", "Work that spans sessions", "gsd-spec-phase, gsd-plan-phase, gsd-execute-phase, gsd-verify-work, gsd-pause-work, gsd-debug.", "Denied in repositories on the standard: gsd-ship, cross-AI convergence."],
    ["bi", "Official and Anthropic", "Depth where it matters", "claude-security (security scanning with a verifier panel), code-review, frontend-design, mcp-server-dev.", "Installed by the full profile. new-skill calls skill-creator for evals when it is installed."],
  ];
  return (
    <Page
      crumb="Reference"
      title="Packs and cost"
      lede="Bearing works alongside open-source packs. Where a step calls a pack's skill, the workflow names it and Bearing adds its own gates around it."
      toc={[
        { id: "packs", label: "What comes from where" },
        { id: "cost", label: "What it costs in context" },
      ]}
    >
      <h2 id="packs">What comes from where</h2>
      <div className="pack-grid">
        {packs.map(([k, name, role, list, note]) => (
          <div className="card pack" key={name} style={{ ["--c" as string]: `var(--${k})` }}>
            <span className="eyebrow">
              <i className="dot" /> {name}
            </span>
            <h3>{role}</h3>
            <p>{list}</p>
            <p className="meta">{note}</p>
          </div>
        ))}
      </div>
      <p>
        The <code>standard</code> install profile adds Superpowers, gstack, GSD Core and impeccable. <code>full</code> adds the rest.{" "}
        <code>docs/THIRD_PARTY.md</code> has every install command and licence.
      </p>
      <h2 id="cost">What it costs in context</h2>
      <p>
        Only skill names and descriptions load every session. {data.skills.length} Bearing skills at 220 characters or fewer each come to at most
        about {Math.round((data.skills.length * 240) / 4000)}k tokens, before any skill body.
      </p>
      <p>
        Claude Code caps that listing at about 1% of the context window. Past the cap, some skills are listed by name only, which is why every
        Bearing name says its job (docs/INSTALL.md, "Keep the skill listing lean").
      </p>
      <p>
        A skill body loads only when its description matches, and its references only when a step reads them. The repository AGENTS.md template is
        about 3,000 characters. Stack detail lives in path-scoped rules that cost nothing until a matching file is opened.
      </p>
      <ul>
        <li>
          <code>install.sh --profile minimal</code> installs the Bearing plugins and the env file, and no packs.
        </li>
        <li>
          <code>npx skills remove &lt;name&gt; -g</code> drops one skills-CLI pack.
        </li>
        <li>Keep the CLAUDE.md snapshot under twenty lines. Every line is paid for on every turn.</li>
      </ul>
    </Page>
  );
}

const HARNESSES = [
  ["Claude Code", "via the CLAUDE.md import", ".claude/rules", "plugin hook"],
  ["Cursor", "yes", ".cursor/rules/*.mdc globs", "beforeShellExecution hook"],
  ["Codex CLI", "yes", "by directory only", "PreToolUse hook"],
  ["Gemini CLI", "GEMINI.md imports it", "none", "BeforeTool hook"],
  ["GitHub Copilot", "yes", ".github/instructions applyTo", "preToolUse hook"],
  ["OpenCode", "yes", "none", "plugin tool.execute.before"],
  ["Windsurf", "yes", ".devin/rules glob trigger", "pre_run_command hook"],
  ["Cline", "yes", ".clinerules paths", "PreToolUse hook"],
  ["Zed", "yes", "none", "no hooks; always_deny setting"],
  ["Kiro", "yes", ".kiro/steering fileMatch", "PreToolUse hook"],
];

export function Harnesses() {
  return (
    <Page
      crumb="Reference"
      title="Other harnesses"
      lede="The standard lives in AGENTS.md, the gate in the Makefile and CI, and the guard in one script, so it does not depend on one harness. One command sets a repository up for another."
      toc={[
        { id: "setup", label: "Set one up" },
        { id: "matrix", label: "What holds where" },
      ]}
    >
      <h2 id="setup">Set one up</h2>
      <Code>{`bash ~/bearing/install.sh --no-claude
~/bearing/plugins/bearing/bin/brg-harness cursor     # or codex, gemini, copilot, opencode, windsurf, cline, zed, kiro, all`}</Code>
      <p>
        It converts the path-scoped rules to that harness's rule files and points its instructions at AGENTS.md. It vendors the guard and its hook
        adapters under <code>.bearing/</code>; commit them. Then it installs the skills into the harness's skills folder.
      </p>
      <h2 id="matrix">What holds where</h2>
      <div className="tbl-wrap">
        <table className="tbl">
          <thead>
            <tr>
              <th>Harness</th>
              <th>Reads AGENTS.md</th>
              <th>Path-scoped rules</th>
              <th>Blocks a publish command</th>
            </tr>
          </thead>
          <tbody>
            {HARNESSES.map((h) => (
              <tr key={h[0]}>
                {h.map((c, i) => (
                  <td key={i}>{i === 0 ? <b style={{ color: "var(--ink)" }}>{c}</b> : c}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="muted">
        On every harness, the pre-push hook still asks a person for the branch name, the commit hooks still check shape and formatting, and{" "}
        <code>make check</code> and CI are still the gate. The adapters for Codex, Copilot, OpenCode, Windsurf, Cline and Kiro follow each tool's
        documentation and are marked unverified until someone runs them. Cursor and Gemini CLI have been run for real.
      </p>
    </Page>
  );
}

export function Versioning() {
  return (
    <Page crumb="Reference" title="Versioning" lede="Semantic versions, pinned per repository, upgraded on your schedule.">
      <div className="list">
        <div>
          <b>What a version means</b>A minor release adds skills, adapters, template files or guard verbs; nothing you use changes meaning. A major
          release renames or removes a skill, or changes a hook contract or what a gate counts. A patch fixes without adding.
        </div>
        <div>
          <b>Pinning</b>Each repository's settings name the marketplace by the kit's git URL: the public repository, or your fork when{" "}
          <code>BEARING_KIT_REMOTE</code> points at one. The vendored guard carries the version it came from. <code>doctor</code> says when the
          installed kit has moved past it.
        </div>
        <div>
          <b>Upgrading</b>
          <code>/bearing:upgrade-tools</code> updates the kit and the packs, prints versions before and after, and reruns the doctor. Read{" "}
          <code>CHANGELOG.md</code> for each version you cross.
        </div>
        <div>
          <b>Where to report</b>Open an issue or a pull request on{" "}
          <a href="https://github.com/Deepta-AI/bearing">github.com/Deepta-AI/bearing</a> for bugs and proposals; <code>CONTRIBUTING.md</code> has the
          flow. Report a vulnerability in the kit privately, as <code>SECURITY.md</code> describes.
        </div>
      </div>
    </Page>
  );
}

const FAQ: [string, React.ReactNode][] = [
  ["doctor says the plugin is missing right after install", <>Restart the harness; plugins load at start. Still missing? Check that <code>claude plugin list</code> shows <code>bearing@bearing</code>. If it does not, rerun <code>install.sh</code> and read its summary line.</>],
  ["A skill did not fire on my phrase", <>Name it: type <code>/bearing:merge-request</code>, or say "use the merge-request skill". With many skill packs installed, Claude Code may list it by name only; trim what you load (docs/INSTALL.md, "Keep the skill listing lean"). If the phrase should have worked, propose it in a pull request to the skill's description.</>],
  ["make check says gates were skipped", <>The summary reads <code>check: R gates run, S skipped</code>, and the skipped gates need a tool that is not installed. <code>make doctor</code> names it. Install it, or run <code>BEARING_ALLOW_SKIP=1 make check</code> locally to see the rest. CI never skips.</>],
  ["The guard blocked a command I know is safe", <>It fails closed: a command it cannot read is refused. Run it yourself in a terminal. If a verb is wrong for the team, change the table in <code>plugins/bearing/bin/brg-guard</code> in the kit; every adapter regenerates from it.</>],
  ["git push is refused inside the harness", <>That is the standard working. <code>/bearing:merge-request</code> prints the push command. Run it in your own terminal, where the pre-push hook asks for the branch name.</>],
  ["The ticket step says tracker: none", <><code>BEARING_TRACKER</code> is unset or <code>none</code>, so ticket writes are skipped. That is valid. To connect a tracker, fill the env file and check it with <code>brg-tracker config</code>.</>],
  ["The doctor says MISSING on GitHub files", <>It accepts either host's CI and change template; MISSING means neither exists. Set <code>BEARING_GIT_HOST=github</code> and run <code>/bearing:onboard-repo</code> again; it copies only that host's files.</>],
  ["The marketplace add fails on a fork's SSH URL", <>Clone the fork first and pass the path: <code>bash install.sh --remote ~/bearing</code>. Or set <code>BEARING_KIT_REMOTE</code> to a URL your machine can reach.</>],
  ["GSD Core warns about the Node version", <>GSD Core wants Node 24; the rest of the kit runs on 22. Upgrade Node, or install with <code>--skip-gsd</code> and add GSD Core later.</>],
];

export function Faq() {
  return (
    <Page crumb="Reference" title="Troubleshooting" lede="Find the line you saw, then open it for the fix.">
      <div className="faq">
        {FAQ.map(([q, a]) => (
          <details key={q}>
            <summary>{q}</summary>
            <div>{a}</div>
          </details>
        ))}
      </div>
    </Page>
  );
}

export function Rules() {
  return (
    <Page crumb="Reference" title="Rules" lede="What the workflow never bends, and what enforces each rule.">
      <div className="list rules">
        <div>
          <b>One skill per step</b>Every step names the one skill the workflow runs, whichever pack provides it. When that is another pack's skill,
          Bearing calls it and adds its own gates.
        </div>
        <div>
          <b>The agent never pushes</b>No push, merge, tag, deploy or change request from the agent. Hooks and permissions enforce it; you run the
          printed command. One exception is opt-in: list a repository's push URL in <code>BEARING_AUTO_PUSH</code>, and the Stop hook pushes its task
          branch after the gate, from a fresh clone.
        </div>
        <div>
          <b>Gates count what they checked</b>Every check fails on empty input and prints how many things it verified. A pass over zero items is a
          bug.
        </div>
        <div>
          <b>Reviews are verified</b>Code review runs gstack /review with the stack checklists. An independent agent confirms every Critical and High
          before it is reported.
        </div>
        <div>
          <b>Everything traces</b>Requirement to story to criterion to test case to commit to ticket. <code>traceability</code> proves the chain and
          fails on a gap.
        </div>
        <div>
          <b>Nothing is chosen silently</b>
          <code>tech-decision</code> shows the options and a recommendation. A person decides, and an ADR records it.
        </div>
        <div>
          <b>One task per session</b>Run <code>session-handoff</code> before pausing. The next session starts from that state.
        </div>
        <div>
          <b>Prose is human</b>No em dashes, no filler, no AI attribution in commits or documents. The commit hook and <code>prose-lint</code>{" "}
          enforce it.
        </div>
      </div>
    </Page>
  );
}
