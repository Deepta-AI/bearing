import { Link } from "react-router";
import { Code, Page } from "../components/ui";
import { data } from "../lib/data";

export function GetStarted() {
  return (
    <Page
      title="Get started"
      lede="Install once per machine, then put a repository on the standard and start a task. Each step ends with a line you can check; if yours differs, Troubleshooting has the fix."
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
        <a href="https://github.com/Deepta-AI/bearing">github.com/Deepta-AI/bearing</a>. There are two ways in.
      </p>
      <h2 id="plugin">The plugin only</h2>
      <p>Inside Claude Code 2.1 or newer:</p>
      <Code>{`/plugin marketplace add Deepta-AI/bearing
/plugin install bearing@bearing`}</Code>
      <p>
        That gives every skill, the seven subagents, and the hooks with the guard behind them. It writes no env file (the tracker stays{" "}
        <code>none</code> until you copy <code>plugins/bearing/templates/user/bearing.env</code> to <code>~/.config/bearing/bearing.env</code>), installs no companion
        packs and leaves no checkout at <code>~/bearing</code>. For those, use the full install below.
      </p>

      <h2 id="install">Install on this machine</h2>
      <p>
        The full install needs a coding harness (Claude Code 2.1 or newer for the plugin), git, Node 22 or newer, make and jq. It adds the env file,
        a personal <code>CLAUDE.md</code> starter, the companion packs for the profile, and a doctor run. A team on a fork clones the fork and sets{" "}
        <code>BEARING_KIT_REMOTE</code>.
      </p>
      <div className="steps">
        <div className="stepcard">
          <div className="n">Step 1</div>
          <h3>Clone and install</h3>
          <Code>{`git clone https://github.com/Deepta-AI/bearing ~/bearing
bash ~/bearing/install.sh`}</Code>
          <p className="expect">
            Last line: <code>install.sh: N installed, M already present, K skipped, 0 failed</code>
          </p>
        </div>
        <div className="stepcard">
          <div className="n">Step 2</div>
          <h3>Configure</h3>
          <p>
            Edit <code>~/.config/bearing/bearing.env</code>. It lives outside every repository with mode 600. <code>BEARING_TRACKER=none</code> is a valid
            answer.
          </p>
          <Code>{`~/bearing/plugins/bearing/bin/brg-tracker config`}</Code>
          <p className="expect">
            First line: <code>tracker: none (from file)</code> or your tracker's name.
          </p>
        </div>
        <div className="stepcard">
          <div className="n">Step 3</div>
          <h3>Restart and check</h3>
          <p>Plugins load when the harness starts. Then, in any repository:</p>
          <Code>{`/bearing:doctor`}</Code>
          <p className="expect">
            Last line: <code>brg-doctor: N checks, 0 missing, M optional</code>. A <code>MISSING</code> line names its own fix.
          </p>
        </div>
      </div>

      <h2 id="repo">Put a repository on the standard</h2>
      <p>A new repository is scaffolded for its stack; an existing one is adopted without overwriting anything, and each conflict is written beside the file as <code>.bearing-new</code>.</p>
      <Code>{`/bearing:new-repo go-api InvoiceService       # a new repository
/bearing:onboard-repo --stack react-web      # an existing one`}</Code>
      <p className="muted">
        Stacks: {data.stacks.join(", ")}.
      </p>
      <p>
        Every file this writes, and the ones on your machine, are on <Link to="/files">Default files</Link> with their full contents and what you
        may change.
      </p>

      <h2 id="task">Start a task</h2>
      <Code>{`/bearing:start-task TASK-142 InvoiceTotals`}</Code>
      <p>
        It creates <code>feature/TASK-142-InvoiceTotals</code> and the state file the next session resumes from, and ends with <code>Next:</code>{" "}
        and the skill to run. From there, follow the <Link to="/flows/feature">feature flow</Link> or ask <code>/bearing:workflow</code> what comes next. You
        can also just say what you want ("start task TASK-142"); Claude loads the matching skill.
      </p>

      <h2 id="profiles">Install profiles</h2>
      <Code>{`bash ~/bearing/install.sh                     # standard: the kit plus Superpowers, gstack and GSD Core
bash ~/bearing/install.sh --profile full      # plus the other packs the workflow names
bash ~/bearing/install.sh --profile minimal   # the plugin and the env file only
bash ~/bearing/install.sh --dry-run           # print what it would do, touch nothing
bash ~/bearing/install.sh --no-claude         # for another harness only`}</Code>
      <p>
        The installer is idempotent and never overwrites your env file. Upgrade with <code>/bearing:upgrade-tools</code>; uninstall with{" "}
        <code>bash ~/bearing/install.sh --uninstall</code>. Every option is in <code>docs/INSTALL.md</code>.
      </p>
    </Page>
  );
}

export function Concepts() {
  return (
    <Page
      title="How skills work"
      lede="A skill is a written procedure the agent follows every time, so nobody re-types it. Knowing how they load explains why dozens can be installed and why some fire on their own."
      toc={[
        { id: "anatomy", label: "What is inside a skill" },
        { id: "terms", label: "The words you will meet" },
        { id: "writing", label: "Writing one" },
      ]}
    >
      <h2 id="anatomy">What is inside a skill</h2>
      <p>
        A skill is a folder with a <code>SKILL.md</code> file. At the start of a session the agent reads only each skill's one-line description, a
        few tokens each, and loads the full instructions when a request matches. That is why the description matters most: it decides whether the
        skill fires.
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
            <b>Description</b>What it does, then "Use when" and the phrases a developer would say. Too vague and it never fires; too broad and it fires on everything.
          </div>
          <div>
            <b>Asked for or typed</b>Every Bearing skill loads when your request matches its description, and every one can be typed as{" "}
            <code>/bearing:&lt;name&gt;</code>. With many packs installed, Claude Code may list some skills by name only; the install guide's "Keep the
            skill listing lean" section says what to trim.
          </div>
          <div>
            <b>Works alone</b>Every input names a fallback: another place to look, one question, or a minimal version. Another skill is the fuller path, never a prerequisite.
          </div>
          <div>
            <b>Gates print counts</b>A check that examined nothing did not pass. Every check fails on empty input and says how many things it verified.
          </div>
        </div>
      </div>

      <h2 id="terms">The words you will meet</h2>
      <div className="list">
        <div>
          <b>Slash command</b>A skill you type: <code>/bearing:merge-request</code>, <code>/office-hours</code>. In Claude Code a plugin's skills are
          reachable as <code>/plugin:name</code>, so every Bearing skill is <code>/bearing:&lt;name&gt;</code>.
        </div>
        <div>
          <b>Subagent</b>A separate agent with a clean context and its own tool limits, named like <code>bearing:reviewer</code>. The reviewer, verifier, security auditor, explorer and critic are read-only; the test writer works in a worktree; the doc writer edits only <code>docs/</code>.
        </div>
        <div>
          <b>Hook</b>A script the harness runs at a moment: session start, before a shell command, after an edit. Hooks enforce what prose cannot, such as never pushing.
        </div>
        <div>
          <b>Plugin</b>How skills, agents and hooks ship together and install in one command. Bearing is one; other harnesses take the same skills through the skills CLI.
        </div>
        <div>
          <b>AGENTS.md and CLAUDE.md</b>Always-on notes, not skills. AGENTS.md is the standard every agent reads; CLAUDE.md imports it. Every line is paid for on every turn, so both stay short.
        </div>
        <div>
          <b>Rules</b><code>.claude/rules/*.md</code> files with a <code>paths:</code> list load only when a matching file is touched, so stack rules cost nothing until you open that stack's code.
        </div>
      </div>

      <h2 id="writing">Writing one</h2>
      <ol>
        <li>Pick one job you re-explain every week. One job per skill.</li>
        <li>Check first whether an installed skill already does the job. If one does, use it and pass it your rules instead of writing another.</li>
        <li>
          Run <code>/bearing:new-skill</code>: it scaffolds the folder to the conventions and runs the lints, then hands the skill to{" "}
          <code>skill-creator</code>, which runs your cases with and without the skill and grades both. A skill that does not pass more of its cases
          than the no-skill run is not added.
        </li>
        <li>Add to the Gotchas every time the skill surprises you.</li>
      </ol>
    </Page>
  );
}

export function Config() {
  return (
    <Page
      title="Configuration"
      lede="One file per machine, never inside a repository: ~/.config/bearing/bearing.env, mode 600, KEY=value one per line. An environment variable of the same name wins over the file, so CI and one-off shells override it without editing."
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
        <code>brg-tracker config</code> shows each value and where it came from, and whether a credential is set. It never prints the credential.
      </p>
      <Code>{`tracker: jira (from file)
env file: /home/you/.config/bearing/bearing.env
url: https://you.atlassian.net
project: PROJ
auth: token set
id prefix: PROJ (ids look like PROJ-N)`}</Code>
      <p className="muted">
        With <code>BEARING_TRACKER=none</code> every ticket write exits 3 and prints <code>tracker: none</code>; the skills treat that as skipped, never as
        a failure. Adapter detail per tracker is in <code>docs/TRACKERS.md</code>.
      </p>
    </Page>
  );
}

export function Security() {
  return (
    <Page
      title="Security model"
      lede="What the kit refuses to do, and the mechanism that refuses it. Prose asks; hooks, the guard and git enforce."
    >
      <div className="list rules">
        <div>
          <b>Credentials never enter a repository or the conversation</b>They live in the env file (mode 600). Tracker adapters pass tokens to curl through a config file on a pipe, never on the command line. Repository settings deny reading <code>.env</code>, keys, keystores and cloud credentials.
        </div>
        <div>
          <b>One verb table, fail closed</b><code>plugins/bearing/bin/brg-guard</code> blocks {data.guardVerbs} verbs: push, history rewrites, branch and tag deletion, merges and releases on glab and gh, package publishing, image pushes, terraform apply and destroy, and deploy tools. It sees through <code>sudo</code>, <code>env</code>, <code>sh -c</code>, <code>eval</code>, <code>xargs</code> and <code>git -C</code>, and refuses a command it cannot read. Every hook and deny list is generated from that one table.
        </div>
        <div>
          <b>Read-only agents</b>The reviewer, verifier, security auditor, explorer and critic run under the guard's read-only mode: a command passes only when every program in it only reads.
        </div>
        <div>
          <b>A push needs a person</b>The pre-push hook asks for the branch name on the terminal, which no agent can type. This holds on every harness, hooks or not.
        </div>
        <div>
          <b>Least-privilege settings</b><code>.claude/settings.json</code> allows read-only tools and make targets, asks for commits and dependency changes, and denies publishing, history rewriting, deployed environments and secrets.
        </div>
        <div>
          <b>Secret scanning</b>The pre-commit hook refuses staged files with token shapes; CI runs the host's secret detection; <code>secrets</code> keeps the inventory and the leak response.
        </div>
      </div>
      <p className="muted">
        A weakness in the kit itself goes privately through GitHub's vulnerability reporting on{" "}
        <a href="https://github.com/Deepta-AI/bearing/security/advisories/new">Deepta-AI/bearing</a>, per <code>SECURITY.md</code>.
      </p>
    </Page>
  );
}

export function Packs() {
  const packs = [
    ["sp", "Superpowers", "Discipline", "brainstorming, writing-plans, executing-plans, test-driven-development, systematic-debugging, verification-before-completion, writing-skills.", "Not used: branch-finishing defaults that push; merge-request covers that step."],
    ["gs", "gstack", "Judgement and live checks", "/office-hours, /plan-ceo-review, /plan-eng-review, /design-consultation, /review, /investigate, /qa, /cso, /design-review, /canary, /retro.", "Denied in repositories on the standard: cookie import, cross-model skills, pair-agent, deploy skills."],
    ["gsd", "GSD Core", "Work that spans sessions", "gsd-new-project, gsd-plan-phase, gsd-execute-phase, gsd-verify-work, gsd-pause-work, gsd-debug.", "Denied in repositories on the standard: gsd-ship, cross-AI convergence."],
    ["bi", "Official and Anthropic", "Depth where it matters", "claude-security (verified security scanning), skill-creator (skill evals), frontend-design, mcp-server-dev.", "Installed by the full profile or the marketplace."],
  ];
  return (
    <Page
      title="Packs and cost"
      lede="The kit works alongside open-source packs. Where a step calls a pack's skill, the workflow names it and Bearing adds its own gates around it."
      toc={[
        { id: "packs", label: "What comes from where" },
        { id: "cost", label: "What it costs in context" },
      ]}
    >
      <h2 id="packs">What comes from where</h2>
      <div className="steps">
        {packs.map(([k, name, role, list, note]) => (
          <div className="stepcard" key={name} style={{ borderTop: `3px solid var(--${k})` }}>
            <div className="n" style={{ color: `var(--${k})` }}>
              {name}
            </div>
            <h3>{role}</h3>
            <p>{list}</p>
            <p className="expect">{note}</p>
          </div>
        ))}
      </div>
      <p>
        The <code>standard</code> install profile adds Superpowers, gstack and GSD Core; <code>full</code> adds the rest. Every install command and
        licence is in <code>docs/THIRD_PARTY.md</code>.
      </p>
      <h2 id="cost">What it costs in context</h2>
      <p>
        Only names and descriptions are always loaded: {data.skills.length} Bearing skills at 220 characters or fewer each is at most about{" "}
        {Math.round((data.skills.length * 240) / 4000)}k tokens a session, before any skill body. Claude Code caps that listing at about 1% of the
        context window; past the cap, some skills are listed by name only, which is why every Bearing name says its job (docs/INSTALL.md, "Keep the
        skill listing lean"). A body loads only when its description matches, and its references only when a step reads them. The repository's AGENTS.md
        is about 1.5k tokens; stack detail lives in path-scoped rules that cost nothing until a matching file is opened.
      </p>
      <ul>
        <li>
          <code>install.sh --profile minimal</code> installs only the plugin and the env file.
        </li>
        <li>
          <code>npx skills remove &lt;name&gt; -g</code> drops one skills-CLI pack.
        </li>
        <li>Keep the CLAUDE.md snapshot under twenty lines; every line is paid for on every turn.</li>
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
      title="Other harnesses"
      lede="The standard lives in AGENTS.md, the gate in the Makefile and CI, and the guard in one script, so it does not depend on one harness. One command sets a repository up for another."
      toc={[
        { id: "setup", label: "Set one up" },
        { id: "matrix", label: "What holds where" },
      ]}
    >
      <h2 id="setup">Set one up</h2>
      <Code>{`bash ~/bearing/install.sh --no-claude
~/bearing/plugins/bearing/bin/brg-harness cursor     # or codex, gemini, copilot, opencode, windsurf, cline, zed, kiro`}</Code>
      <p>
        It converts the path-scoped rules to that harness's rule files, points its instructions at AGENTS.md, vendors the guard with its hook
        adapters under <code>.bearing/</code> (commit them), and installs the skills into its skills folder.
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
        On every harness the pre-push hook still asks a person for the branch name, the commit hooks still check shape and formatting, and{" "}
        <code>make check</code> and CI are still the gate. The adapters for Codex, Copilot, OpenCode, Windsurf, Cline and Kiro follow their
        documentation and are marked unverified until someone runs them; Cursor and Gemini CLI have been exercised.
      </p>
    </Page>
  );
}

export function Versioning() {
  return (
    <Page title="Versioning" lede="Semantic versions, pinned per repository, upgraded on your schedule.">
      <div className="list">
        <div>
          <b>What a version means</b>A minor release adds skills, adapters, template files or guard verbs; nothing you use changes meaning. A major release renames or removes a skill, changes a hook contract or what a gate counts. Patches fix without adding.
        </div>
        <div>
          <b>Pinning</b>Each repository's settings name the marketplace by the kit's git URL: the public repository, or your fork when{" "}
          <code>BEARING_KIT_REMOTE</code> points at one. The vendored guard carries the version it came from, and <code>doctor</code> says when the installed kit has moved past it.
        </div>
        <div>
          <b>Upgrading</b><code>/bearing:upgrade-tools</code> updates the kit and the packs, prints versions before and after, and reruns the doctor. Read <code>CHANGELOG.md</code> for the versions you cross.
        </div>
        <div>
          <b>Where to report</b>Bugs and proposals go to an issue or a pull request on{" "}
          <a href="https://github.com/Deepta-AI/bearing">github.com/Deepta-AI/bearing</a> (<code>CONTRIBUTING.md</code> has the flow). A vulnerability in
          the kit goes privately, per <code>SECURITY.md</code>.
        </div>
      </div>
    </Page>
  );
}

const FAQ: [string, React.ReactNode][] = [
  ["doctor says the plugin is missing right after install", <>Restart the harness; plugins load at start. If it is still missing, <code>claude plugin list</code> should show <code>bearing@bearing</code>; if not, rerun <code>install.sh</code> and read its summary line.</>],
  ["A skill did not fire on my phrase", <>Name it: type <code>/bearing:merge-request</code>, or say "use the merge-request skill". On a machine with many skill packs, Claude Code may list it by name only; trim what you load (docs/INSTALL.md, "Keep the skill listing lean"). If the phrase should have worked, propose it as a pull request to the skill's description.</>],
  ["make check says gates were skipped", <>A tool a gate needs is not installed; the skipped names are listed. Install it (<code>make doctor</code> names it), or locally run <code>BEARING_ALLOW_SKIP=1 make check</code> to see the rest. CI never skips.</>],
  ["The guard blocked a command I know is safe", <>It fails closed: a command it cannot read is refused. Run it yourself in a terminal. If a verb is wrong for the team, change the table in <code>plugins/bearing/bin/brg-guard</code> in the kit; every adapter regenerates from it.</>],
  ["git push is refused inside the harness", <>That is the standard working. <code>/bearing:merge-request</code> prints the push command; run it in your own terminal, where the pre-push hook asks for the branch name.</>],
  ["The ticket step says tracker: none", <><code>BEARING_TRACKER</code> is unset or <code>none</code>, so ticket writes are skipped. That is valid. Fill the env file to connect one and check with <code>brg-tracker config</code>.</>],
  ["The doctor says MISSING on GitHub files", <>It accepts either host. Set <code>BEARING_GIT_HOST=github</code> and run <code>/bearing:onboard-repo</code> again; it copies only that host's files.</>],
  ["The marketplace add fails on a fork's SSH URL", <>Clone the fork first and pass the path: <code>bash install.sh --remote ~/bearing</code>, or set <code>BEARING_KIT_REMOTE</code> to a URL your machine can reach.</>],
  ["GSD Core warns about the Node version", <>GSD Core wants Node 24; the rest of the kit is fine on 22. Upgrade Node, or install with <code>--skip-gsd</code> and add it later.</>],
];

export function Faq() {
  return (
    <Page title="Troubleshooting" lede="When the line you see is not the one you expected.">
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
    <Page title="Rules" lede="What the workflow never bends, and what enforces each rule.">
      <div className="list rules">
        <div>
          <b>One skill per step</b>Every step names the one skill the workflow runs, whichever pack provides it. Where that is another pack's skill, Bearing calls it and adds its own gates.
        </div>
        <div>
          <b>The agent never pushes</b>No push, merge, tag, deploy or change request from the agent. Hooks and permissions enforce it; you run the printed command.
        </div>
        <div>
          <b>Gates count what they checked</b>Every check fails on empty input and prints how many things it verified. A pass over zero items is a bug.
        </div>
        <div>
          <b>Reviews are verified</b>Code review runs gstack /review with the stack checklists, and an independent agent confirms every Critical and High before it is reported.
        </div>
        <div>
          <b>Everything traces</b>Requirement to story to criterion to test case to commit to ticket. <code>traceability</code> proves the chain and fails on a gap.
        </div>
        <div>
          <b>Nothing is chosen silently</b><code>tech-decision</code> shows the options and a recommendation; a person decides; an ADR records it.
        </div>
        <div>
          <b>One task per session</b><code>session-handoff</code> before pausing; the next session starts from that state.
        </div>
        <div>
          <b>Prose is human</b>No em dashes, no filler, no AI attribution in commits or documents. The commit hook and <code>prose-lint</code> enforce it.
        </div>
      </div>
    </Page>
  );
}
