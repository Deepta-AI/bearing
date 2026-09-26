import { useState, type CSSProperties } from "react";
import { Link } from "react-router";
import { Code, H2, Note, Page, S } from "../components/ui";
import { data } from "../lib/data";

const LAYERS = [
  {
    n: "1",
    name: "The plugin manifest",
    path: ".claude-plugin/",
    kind: "declares",
    text: "marketplace.json names a marketplace called bearing that holds one plugin; plugin.json names the plugin and its version. Claude Code finds skills/, agents/ and hooks/hooks.json by convention next to it. Nothing else registers anything.",
    to: "/install",
  },
  {
    n: "2",
    name: "Skills",
    path: "skills/*/",
    kind: "the model reads",
    text: "Instructions for one step each. Only the name and description sit in every session; the body loads when the skill is invoked, and its references/ load only when a step says to read them.",
    to: "/skills-work",
  },
  {
    n: "3",
    name: "Subagents",
    path: "agents/*.md",
    kind: "the model reads, in a fork",
    text: "A fresh context with a narrower tool list. Reviewers get Read, Grep and Glob and nothing else; the test writer gets a worktree. They return a report, never a conversation.",
    to: "/agents",
  },
  {
    n: "4",
    name: "Hooks over the guard",
    path: "hooks/ and bin/brg-guard",
    kind: "the machine enforces",
    text: "Six events, each a few lines of shell that turn the event's JSON into arguments for one script. The guard decides; the adapter only translates. The same guard serves eight other harnesses.",
    to: "/session",
  },
  {
    n: "5",
    name: "Scripts",
    path: "bin/brg-*",
    kind: "the machine does",
    text: "Deterministic work that a skill calls instead of improvising: scaffold, adopt, the tracker adapters, autopilot's gates, the checklists. A skill's allowed-tools grants exactly these calls.",
    to: "/scripts",
  },
];

const WALLS = [
  { key: "agents", name: "AGENTS.md, rule 2", kind: "prose", says: "Never push, open a merge request, merge, tag or deploy.", where: "templates/repo/AGENTS.md" },
  { key: "deny", name: "settings.json deny", kind: "the harness", says: "Bash(git push:*) is in the deny list, so Claude Code refuses the call whatever the model intends.", where: "templates/repo/.claude/settings.json" },
  { key: "guard", name: "PreToolUse guard", kind: "the hook", says: "brg-guard takes the command apart, so env, &&, $( ) or an alias do not hide it. Exit 2.", where: "hooks/scripts/block-publish.sh" },
  { key: "prepush", name: ".githooks/pre-push", kind: "git", says: "A person must confirm at a terminal within 60 seconds. An agent has no terminal, so the read fails.", where: "templates/repo/.githooks/pre-push" },
];

function Walls() {
  const [up, setUp] = useState<Record<string, boolean>>({ agents: true, deny: true, guard: true, prepush: true });
  const [run, setRun] = useState(0);
  const stopAt = WALLS.findIndex((w) => up[w.key]);
  const stop = stopAt < 0 ? WALLS.length : stopAt;
  return (
    <figure className="walls wide panel">
      <div className="walls-track">
        <div className="agent-end">Agent runs git push</div>
        {WALLS.map((w, i) => (
          <div key={w.key} className={`wall ${up[w.key] ? "up" : "down"} ${run && i === stop ? "hit" : ""}`}>
            <button type="button" aria-pressed={up[w.key]} onClick={() => setUp((u) => ({ ...u, [w.key]: !u[w.key] }))}>
              {up[w.key] ? "In place" : "Removed"}
            </button>
            <b>{w.name}</b>
            <span className="kind">{w.kind}</span>
            <p>{w.says}</p>
          </div>
        ))}
        <div className={`remote-end ${run && stop === WALLS.length ? "reached" : ""}`}>The remote</div>
        {run > 0 && <span key={run} className="packet" style={{ ["--stop" as string]: stop } as CSSProperties} />}
      </div>
      <div className="an-ctl">
        <button type="button" className="primary" onClick={() => setRun((r) => r + 1)}>
          Send a push
        </button>
        <span className="walls-out" aria-live="polite">
          {run > 0 && (stop < WALLS.length ? `Stopped by ${WALLS[stop].name}.` : "Nothing stopped it. Remove fewer walls.")}
        </span>
      </div>
      <figcaption>Switch walls off to see that each one holds alone. The kit keeps all four because each can fail on its own: a model ignores prose, a settings file is edited, a hook is not installed, a hook path is changed.</figcaption>
    </figure>
  );
}

export function Architecture() {
  return (
    <Page
      title="The five layers"
      lede="Bearing is five kinds of file, loaded by Claude Code in five different ways. Knowing which layer a behaviour lives in tells you where to change it and what can override it."
      toc={[
        { id: "layers", label: "The layers" },
        { id: "loading", label: "How Claude Code loads them" },
        { id: "repo", label: "What lands in a repository" },
        { id: "depth", label: "Defence in depth" },
        { id: "neutral", label: "Company-neutral by construction" },
      ]}
      sources={[".claude-plugin/plugin.json", ".claude-plugin/marketplace.json", "hooks/hooks.json", "templates/repo/.claude/settings.json"]}
    >
      <H2 id="layers">The layers</H2>
      <div className="stack-diagram wide">
        {LAYERS.map((l) => (
          <Link key={l.n} to={l.to} className={`sd-layer k-${l.kind.startsWith("the machine") ? "machine" : l.kind === "declares" ? "decl" : "model"}`}>
            <span className="sd-n">{l.n}</span>
            <span className="sd-head">
              <b>{l.name}</b>
              <code>{l.path}</code>
            </span>
            <span className="sd-kind">{l.kind}</span>
            <span className="sd-text">{l.text}</span>
          </Link>
        ))}
      </div>
      <p>
        Layers 2 and 3 are prose: the model reads them and usually complies. Layers 4 and 5 are code: they run whatever the model thinks. Every rule in the kit
        that must hold without exception has a copy in layer 4 or in the repository's own git hooks and gate.
      </p>

      <H2 id="loading">How Claude Code loads them</H2>
      <ol className="steps">
        <li>
          <strong>Install.</strong> <code>install.sh</code> runs <code>claude plugin marketplace add</code> on the kit's path or remote, then{" "}
          <code>claude plugin install bearing@bearing</code>. Claude Code copies the plugin to <code>~/.claude/plugins/cache/bearing/bearing/{data.version}/</code>.
          That copy, not your checkout, is what runs.
        </li>
        <li>
          <strong>Session start.</strong> Each auto skill's <code>name</code> and <code>description</code> enter the context (a command skill stays out of the
          model's list until you type it; <code>lint-skills</code> caps a description at 300 characters), together with
          the repository's <code>CLAUDE.md</code>, which imports <code>AGENTS.md</code> on its first line, and the rules in <code>.claude/rules/</code> that
          have no <code>paths:</code>. <code>lint-budget</code> holds this to about {data.settings.sessionTokens.toLocaleString("en")} tokens a session.
        </li>
        <li>
          <strong>Hooks register.</strong> <code>hooks/hooks.json</code> is read; each command uses <code>${"${CLAUDE_PLUGIN_ROOT}"}</code>, which resolves to the
          cached copy. SessionStart fires at once.
        </li>
        <li>
          <strong>A skill is invoked</strong> when you type its name (command skills, <code>disable-model-invocation: true</code>) or when the model matches
          your words to a description (auto skills). Only then does the body load, and only then do its <code>allowed-tools</code> apply.
        </li>
        <li>
          <strong>A path rule loads</strong> when the model touches a file its <code>paths:</code> globs match: <code>code.md</code> for <code>src/**</code>,{" "}
          <code>database.md</code> for migrations, the stack's rules file for its sources.
        </li>
      </ol>
      <Note title="Why your edit is not running">
        <p>
          Claude Code caches a plugin under its version, and <code>claude plugin update</code> keeps an existing copy of the same version. That is why 0.4.0
          existed: to move the version so installed machines refreshed. While developing, reinstall, or run sessions with <code>--plugin-dir</code>.
        </p>
      </Note>

      <H2 id="repo">What lands in a repository</H2>
      <p>
        The plugin lives on the developer's machine. A product repository gets its own copy of the standard from <code>templates/repo/</code>, so it keeps
        working for a teammate on another harness, in CI, and on a clone where the plugin was never installed.
      </p>
      <div className="tablewrap">
        <table>
          <thead>
            <tr>
              <th>File</th>
              <th>Loaded by</th>
              <th>Job</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><code>AGENTS.md</code></td>
              <td>every harness</td>
              <td>The twelve ground rules, the task loop, the report shape. Under 3,600 bytes by <code>lint-budget</code>.</td>
            </tr>
            <tr>
              <td><code>CLAUDE.md</code></td>
              <td>Claude Code</td>
              <td><code>@AGENTS.md</code> on line one, then the repository snapshot: stack, host, tracker, trunk.</td>
            </tr>
            <tr>
              <td><code>.claude/settings.json</code></td>
              <td>Claude Code</td>
              <td>The permission model ({data.settings.allow} allow, {data.settings.ask} ask, {data.settings.deny} deny), the sandbox ({data.settings.domains} network domains), and the marketplace so a fresh clone offers to install Bearing.</td>
            </tr>
            <tr>
              <td><code>.claude/rules/*.md</code></td>
              <td>Claude Code, by path</td>
              <td>Code, testing, database, security, observability, analytics, and the stack's own rules.</td>
            </tr>
            <tr>
              <td><code>.githooks/</code></td>
              <td>git (core.hooksPath)</td>
              <td>commit-msg, pre-commit and pre-push: the rules that hold whoever commits.</td>
            </tr>
            <tr>
              <td><code>Makefile</code>, CI</td>
              <td>make, the pipeline</td>
              <td>The gate. Its check target touches <code>.bearing/state/.check-passed</code>, which the Stop hook reads.</td>
            </tr>
          </tbody>
        </table>
      </div>

      <H2 id="depth">Defence in depth</H2>
      <p>Take the most important rule: the agent never pushes. It is written four times, in four layers that fail independently.</p>
      <Walls />

      <H2 id="neutral">Company-neutral by construction</H2>
      <p>
        Nothing in the kit names a company, a git host or a tracker. Those come from <code>~/.config/bearing/bearing.env</code> (never inside a repository) and
        from placeholders that <S name="brg-scaffold" /> fills: <code>__KIT_REMOTE__</code>, <code>__ORG_ID__</code>, <code>__TRACKER__</code>. The holder of
        the licence is named once, in <code>NOTICE.md</code>. <code>make lint-neutral</code> fails on the phrases a de-branding leaves behind and on tracker
        id literals outside the adapter docs.
      </p>
      <Code cap="where configuration comes from, highest first">{`1. a flag on the command            brg-scaffold ... --host github
2. the environment                  BEARING_GIT_HOST=github
3. ~/.config/bearing/bearing.env    (or the file BEARING_ENV names)
4. the default                      both, none, com.example, the kit's own remote`}</Code>
    </Page>
  );
}
