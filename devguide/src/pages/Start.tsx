import type { ReactNode } from "react";
import { Link } from "react-router";
import { Terminal } from "../components/Terminal";
import { Code, H2, Note, Page, S, Tree } from "../components/ui";
import { data } from "../lib/data";

const READ: [string, ReactNode][] = [
  ["README.md", "What Bearing promises its users, the quickstart, and the last line each step prints."],
  [
    "plugins/bearing/hooks/hooks.json",
    "Every event Bearing acts on and the script each one runs. These are the only places Bearing acts without being asked.",
  ],
  [
    "hooks/scripts/lib.sh and block-publish.sh",
    <>
      How an event's JSON becomes arguments for the guard, and why a missing <code>jq</code> means refuse. See <Link to="/session">chapter 3</Link>.
    </>,
  ],
  [
    "plugins/bearing/bin/brg-guard, the header",
    <>
      The comment at the top: its subcommands and the pattern language of the rule table. See <Link to="/guard">chapter 4</Link>.
    </>,
  ],
  ["plugins/bearing/templates/repo/AGENTS.md", "The twelve ground rules every product repository gives its agents. The guard enforces the ones code can enforce."],
  [
    "plugins/bearing/skills/start-task/SKILL.md",
    <>
      A typical skill: frontmatter, Inputs with fallbacks, Steps, Output contract, Gotchas. See <Link to="/skills-work">chapter 5</Link>.
    </>,
  ],
  [
    "plugins/bearing/bin/brg-scaffold",
    <>
      How a repository is born: three layers of files, placeholders, the lockfile, git and hooks. See <Link to="/scaffold">chapter 7</Link>.
    </>,
  ],
  [
    "Makefile",
    <>
      The <code>check</code> target and each lint behind it. Every one prints a count.
    </>,
  ],
  [
    "bin/gen-guide.py",
    <>
      The stage table (<code>STAGES</code>, <code>CATEGORY</code>): which skill each step runs and which pack provides it.
    </>,
  ],
];

export function Start() {
  const c = data.counts;
  const bin = data.scripts.filter((s) => s.path.startsWith("bin/")).length;
  const pbin = data.scripts.filter((s) => s.path.startsWith("plugins/bearing/bin/")).length;
  const events = new Set(data.hooks.map((h) => h.event)).size;
  return (
    <Page
      crumb="Chapter 1 / Orientation"
      title="Where to start"
      lede={`Bearing looks large (${c.skills} skills, ${c.scripts} scripts), but a handful of ideas repeat through it. Learn them and the layout, and every file becomes predictable.`}
      toc={[
        { id: "idea", label: "The one idea" },
        { id: "loop", label: "Your working loop" },
        { id: "map", label: "The repository map" },
        { id: "read", label: "Nine files, in order" },
        { id: "rules", label: "Rules of the kit" },
        { id: "check", label: "Watch make check" },
      ]}
      sources={["README.md", "CONTRIBUTING.md", "Makefile", ".claude-plugin/plugin.json"]}
    >
      <H2 id="idea">The one idea</H2>
      <p>
        A coding agent follows prose well most of the time. So Bearing writes the workflow as prose: skills, <code>AGENTS.md</code>, rules. Every rule that
        must never break is also backed by something that is not prose: a hook that refuses the command, a permission the harness enforces, a git hook that
        needs a human, a gate that fails the build. For any file in the kit, ask which of the two it is.
      </p>
      <div className="cols">
        <div className="card">
          <h4>What the model reads</h4>
          <p>
            {c.skills} skills, {c.agents} subagent prompts, the repository's <code>AGENTS.md</code>, <code>CLAUDE.md</code> and <code>.claude/rules/</code>. They
            say how to do a step well. The model can ignore them.
          </p>
        </div>
        <div className="card">
          <h4>What the machine enforces</h4>
          <p>
            {c.hooks} hook entries, most over <S name="brg-guard" />; the settings deny list, the sandbox, three git hooks, {c.gates} gates in <code>make check</code>, and
            CI. No argument gets past them.
          </p>
        </div>
      </div>

      <H2 id="loop">Your working loop</H2>
      <p>Work on the kit the way it asks product repositories to work: a task branch, small changes, the gate before every commit.</p>
      <Code cap="once">{`git clone https://github.com/Deepta-AI/bearing ~/bearing && cd ~/bearing   # or your fork
make help        # every target, one line each
make install     # install the plugin from this checkout (runs install.sh)
make doctor      # what this machine has and lacks`}</Code>
      <Code cap="every change">{`make check                        # the gate: ${c.gates} steps, about three minutes
make check-file FILE=plugins/bearing/bin/brg-guard   # the per-file check, run after an edit
make docs                          # regenerate docs/ and both sites' data
make harness-eval ONLY=push        # a real Claude session against the hooks (not in check)`}</Code>
      <Note title="After changing a hook or the guard">
        <p>
          The installed plugin is a copy, cached under its version. Your edit is not live until you reinstall (<code>make install</code>) or bump{" "}
          <code>VERSION</code>. <code>make harness-eval</code> points <code>--plugin-dir</code> at your checkout, so it tests your edit and not the cached copy.
        </p>
      </Note>

      <H2 id="map">The repository map</H2>
      <Tree
        rows={[
          { path: ".claude-plugin/", dir: true, note: "marketplace.json: the marketplace bearing and its four plugins (bearing@bearing, bearing-backend@bearing, bearing-apps@bearing, bearing-genai@bearing)" },
          { path: "plugins/bearing/", dir: true, note: "the required plugin: its own .claude-plugin/plugin.json, LICENSE and README.md, and the folders below" },
          { path: "plugins/*/skills/", dir: true, note: `${c.skills} skill folders across the four plugins, each SKILL.md plus references/, templates/ and scripts/ (${c.skillFiles} files in all)` },
          { path: "plugins/bearing/agents/", dir: true, note: `${c.agents} subagents: reviewer, verifier, security auditor, explorer, test writer, doc writer, critic, PRD drafter` },
          { path: "plugins/bearing/hooks/", dir: true, note: `hooks.json maps ${events} events to ${c.hooks} short adapters in scripts/, which call brg-guard and brg-session` },
          { path: "plugins/bearing/bin/", dir: true, note: `${pbin} brg- scripts: the guard, scaffold and adopt, trackers, autopilot, brg-kit-paths` },
          { path: "plugins/bearing/templates/repo/", dir: true, note: "what every product repository commits: AGENTS.md, CLAUDE.md, settings, rules, git hooks, docs templates" },
          { path: "plugins/bearing/templates/user/", dir: true, note: "the per-developer files install.sh writes: bearing.env and a personal CLAUDE.md" },
          { path: "plugins/bearing-backend/", dir: true, note: "optional plugin: the go, python, node, data-pipeline and infra stack skills and their templates" },
          { path: "plugins/bearing-apps/", dir: true, note: "optional plugin: the react, nextjs, react-native, flutter, ios and android stack skills and their templates" },
          { path: "plugins/bearing-genai/", dir: true, note: "optional plugin, installed by default: the GenAI and ML skills (genai-design, rag, llm-agent, llm-eval, llm-gateway and more) and their templates" },
          { path: "bin/", dir: true, note: `${bin} repository tools, never shipped: the generators, lints and eval harnesses` },
          { path: "tests/", dir: true, note: `${c.tests} test files and ${c.fixtures} fixtures; tests/run.sh runs them inside make check` },
          { path: "evals/", dir: true, note: `${c.evals} skills with measured evals; evals/.pending lists the rest, and it only shrinks` },
          { path: "docs/", dir: true, note: "INSTALL, WORKFLOW, SKILLS, TRACKERS and the reviewed flows.json" },
          { path: "site/", dir: true, note: "the public handbook (how to use Bearing), built from docs/ by bin/gen-guide.py" },
          { path: "devguide/", dir: true, note: "this guide (how Bearing works), built from the whole repository by bin/gen-devguide.py" },
          { path: "install.sh", note: "the installer: plugin, packs, the env file, the doctor" },
          { path: "Makefile", note: `${data.make.length} targets; check is the gate` },
          { path: ".github/workflows/", dir: true, note: `CI on GitHub Actions: ci.yml (checks, scaffolds, bash 3.2, macOS) and docs.yml (both sites to Vercel), ${c.ghJobs} jobs` },
          { path: ".gitlab-ci.yml", note: `the GitLab twin for a mirror: ${c.ciJobs} jobs, each Linux-buildable stack scaffolded in its own image` },
        ]}
      />

      <H2 id="read">Nine files, in order</H2>
      <p>Read these nine in order. Each builds on the one before.</p>
      <ol className="stepcs wide-cards">
        {READ.map(([file, text], i) => (
          <li key={i}>
            <div className="stepc">
              <div className="of">
                {i + 1} of {READ.length}
              </div>
              <h3>
                <code>{file}</code>
              </h3>
              <p>{text}</p>
            </div>
          </li>
        ))}
      </ol>

      <H2 id="rules">Rules of the kit</H2>
      <p>These hold for every file in the repository. The lints enforce most of them, so breaking one usually fails <code>make check</code>.</p>
      <ul>
        <li>
          <strong>The agent prepares; the engineer pushes, merges, tags and deploys.</strong> A skill prints the command. One opt-in exception: where the
          engineer lists a repository's push URL in <code>BEARING_AUTO_PUSH</code>, the Stop hook's <code>brg-push</code> pushes the task branch after the
          gate.
        </li>
        <li>
          <strong>A gate that examined nothing did not pass.</strong> Every check prints what it counted and fails on zero. <code>tests/lint/gate_selfaudit.sh</code>{" "}
          audits the gates themselves.
        </li>
        <li>
          <strong>Every skill works alone.</strong> Each input names its source and a fallback. No skill needs another to have run first.
        </li>
        <li>
          <strong>The kit names no company, host or tracker.</strong> <code>lint-neutral</code> fails on the scars a rename leaves; the holder lives only in{" "}
          <code>NOTICE.md</code>.
        </li>
        <li>
          <strong>Scripts run on macOS bash 3.2 and Linux.</strong> No <code>mapfile</code>, no <code>${"{x,,}"}</code>, no GNU-only flags. CI runs the guard
          and the unit tests in a bash 3.2 image, and the whole suite on macOS.
        </li>
        <li>
          <strong>Generated files are never edited by hand.</strong> <code>lint-docs</code> regenerates them and fails if they changed.
        </li>
        <li>
          <strong>No em dashes anywhere, and no AI attribution in commits.</strong> <code>lint-prose</code> and the <code>commit-msg</code> hook check both.
        </li>
      </ul>

      <H2 id="check">Watch make check</H2>
      <p>The gate, recorded on this checkout. Each line is one gate reporting what it counted.</p>
      <Terminal id="check" height={420} />
    </Page>
  );
}
