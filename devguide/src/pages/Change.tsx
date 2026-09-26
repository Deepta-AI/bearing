import { useState } from "react";
import { Link } from "react-router";
import { Stepper, type Frame } from "../components/Stepper";
import { Code, H2, Note, Page, S } from "../components/ui";
import { data } from "../lib/data";

type Recipe = { id: string; title: string; when: string; touch: string[]; steps: React.ReactNode[]; gates: string[] };

const RECIPES: Recipe[] = [
  {
    id: "skill",
    title: "Add a skill",
    when: "A step nothing installed does well, or a procedure the team repeats.",
    touch: ["skills/<name>/SKILL.md", "evals/<name>/evals.json", "bin/gen-guide.py (CATEGORY, STAGES)", "docs/comparisons.json", "CHANGELOG.md"],
    steps: [
      <>
        Run <S name="new-skill" /> <code>&lt;name&gt;</code> in the kit checkout. It interviews you one question at a time: what it does, three to five
        trigger phrases, command or auto, each input with its fallback, the tools, the gotchas.
      </>,
      <>
        It writes <code>SKILL.md</code> from the template. Keep it under 140 lines; put long checklists in <code>references/</code> and files to copy in{" "}
        <code>templates/</code>.
      </>,
      <>
        Give it a category in <code>CATEGORY</code> and, if it is the main skill for a stage, a row in <code>STAGES</code> in <code>bin/gen-guide.py</code>.
        Add its verdict against the best alternative to <code>docs/comparisons.json</code>; <code>gen-guide.py</code> fails on a skill without one.
      </>,
      <>
        Write <code>evals/&lt;name&gt;/evals.json</code> with two or three realistic prompts and checkable expectations, and run them through
        skill-creator against a no-skill baseline. A skill that does not beat the baseline is not added.
      </>,
      <>
        <code>make docs</code>, then <code>make check</code>. Add the CHANGELOG line under Unreleased.
      </>,
    ],
    gates: ["validate", "lint-skills", "lint-tools", "lint-evals", "lint-docs", "lint-prose"],
  },
  {
    id: "skill-edit",
    title: "Change a skill",
    when: "A skill misses a step, triggers wrongly, or runs a command it has no grant for.",
    touch: ["skills/<name>/SKILL.md", "evals/<name>/evals.json"],
    steps: [
      <>
        Edit the body. A new command in Inputs, Steps or Commands needs a grant in <code>allowed-tools</code>, or a row in{" "}
        <code>bin/lint-skill-tools.allow</code> when the skill only prints it for you.
      </>,
      <>
        A description change moves triggering for every session. Keep "Use when" and three to five quoted phrases, 300 characters at most, and rerun the
        description optimiser with near-miss prompts from neighbouring skills.
      </>,
      <>If the skill has evals, rerun them; add a case for the failure that prompted the change.</>,
      <>
        <code>make lint-skills lint-tools</code> while working, <code>make docs</code> if the description changed, then <code>make check</code>.
      </>,
    ],
    gates: ["lint-skills", "lint-tools", "lint-evals", "lint-docs"],
  },
  {
    id: "guard-rule",
    title: "Add or change a guard rule",
    when: "An agent ran something it should not have, or a safe command was refused.",
    touch: ["bin/brg-guard (verb_rows)", "tests/unit/guard_deny_table.sh", "templates/repo/.claude/settings.json"],
    steps: [
      <>
        Add the row to <code>verb_rows</code> in <code>bin/brg-guard</code> as <code>tool|pattern|label</code>, using the <Link to="/guard#patterns">pattern language</Link>
        . Prefer the narrowest pattern: <code>helm|upgrade</code>, not <code>helm|</code>.
      </>,
      <>
        Add rows to <code>tests/unit/guard_deny_table.sh</code>: a DENY for the command and its disguises (behind env, after &&, inside bash -c), and an
        ALLOW for its nearest safe twin, so the rule cannot grow into a false refusal. Build blocked strings at run time, as the file does, so it never holds
        one on a line.
      </>,
      <>
        Add the matching <code>Bash(...)</code> deny entry to <code>templates/repo/.claude/settings.json</code>. Run <code>brg-harness all</code> in a test
        repository to see the derived policies for the other harnesses.
      </>,
      <>
        <code>make test</code> (the deny table and <code>guard_latency.sh</code>), <code>make check</code>, then <code>make harness-eval ONLY=push,ordinary-work</code>{" "}
        to prove a real session is refused and ordinary work is not.
      </>,
    ],
    gates: ["test (guard_deny_table, guard_latency, guard_readonly)", "lint-shell", "harness-eval"],
  },
  {
    id: "hook",
    title: "Change a hook",
    when: "A new event to act on, or a change in what an event prints or blocks.",
    touch: ["hooks/hooks.json", "hooks/scripts/<adapter>.sh", "bin/brg-guard", "tests/fixtures/hooks/", "tests/unit/guard_harness_gates.sh"],
    steps: [
      <>
        Put the logic in a <code>brg-guard</code> subcommand, not in the adapter. The adapter only reads fields with <code>json_field</code> and calls the
        guard, so the same behaviour reaches every harness.
      </>,
      <>
        Decide how it talks back: exit 2 with stderr (PreToolUse), <code>block_or_print</code> for a <code>{'{"decision": "block"}'}</code> (PostToolUse,
        Stop), plain stdout for context (SessionStart, UserPromptSubmit). The JSON must be all of stdout.
      </>,
      <>
        Never let a hook loop. A Stop hook that can block must honour <code>stop_hook_active</code>.
      </>,
      <>
        Add a fixture under <code>tests/fixtures/hooks/</code> and cases to the hook tests; <code>harness_each.sh</code> runs fixtures through every
        adapter.
      </>,
      <>
        <code>make check</code>, reinstall or bump the version, then <code>make harness-eval</code>. A hook change is not done until a real session proves it.
      </>,
    ],
    gates: ["test (guard_harness_gates, guard_session_stop, harness_each)", "lint-shell", "lint-json", "harness-eval"],
  },
  {
    id: "stack",
    title: "Add a stack",
    when: "A new language or platform lane for scaffold, adopt, review and conventions.",
    touch: ["skills/<lane>/SKILL.md", "skills/<lane>/templates/stack.json", "skills/<lane>/templates/skeleton/", "skills/<lane>/references/", "bin/brg-checklists", ".gitlab-ci.yml"],
    steps: [
      <>
        Create the lane skill with the stack sections: When this skill is active, Layout, On a foreign layout, Rules that matter most, Commands, Gotchas.
      </>,
      <>
        Add <code>templates/stack.json</code> with the required keys and <code>install</code>/<code>tool</code> for the lockfile. That file alone makes{" "}
        <S name="brg-scaffold" /> and <S name="brg-adopt" /> see the stack.
      </>,
      <>
        Write the stack's Makefile (help, setup, check that touches <code>.check-passed</code> and prints <code>check: R gates run, S skipped</code>,
        check-file), both CI files, and a skeleton that passes its own <code>make check</code>.
      </>,
      <>
        Add <code>references/rules.md</code> (copied to <code>.claude/rules/&lt;rules_file&gt;</code>), <code>references/review-checklist.md</code>, and the
        stack's markers to <S name="brg-checklists" /> so reviews pick it up.
      </>,
      <>
        Add a <code>kit:scaffold:&lt;id&gt;</code> job in <code>.gitlab-ci.yml</code> with the stack's own image. <code>scaffold_each_stack.sh</code> finds the
        stack by itself.
      </>,
    ],
    gates: ["lint-skills", "lint-json", "test (scaffold_each_stack, stack_json, gate_selfaudit)", "kit:scaffold:<id> in CI"],
  },
  {
    id: "tracker",
    title: "Add a tracker",
    when: "A team uses a tracker the four adapters do not cover.",
    touch: ["bin/brg-<tracker>", "bin/brg-tracker", "tests/contract/fake_tracker.py", "templates/user/bearing.env", "docs/TRACKERS.md"],
    steps: [
      <>
        Write <code>bin/brg-&lt;tracker&gt;</code> with the same verbs, exit codes (0, 1, 2 usage, 3 skipped) and one line per action. Copy the{" "}
        <code>load_env</code> parser exactly; <code>load_env.sh</code> compares every copy.
      </>,
      <>
        Credentials through a curl config on a pipe; a POST retry that first checks for its own marker; paging capped by{" "}
        <code>BEARING_TRACKER_MAX_PAGES</code>.
      </>,
      <>
        Route it in <S name="brg-tracker" />, add its keys to <code>templates/user/bearing.env</code> and its section to <code>docs/TRACKERS.md</code>.
      </>,
      <>
        Teach <code>fake_tracker.py</code> its API and add cases to <code>tracker_fake_server.sh</code>: retry, paging, a quoted token, a slow call.
      </>,
    ],
    gates: ["test (tracker_fake_server, load_env)", "lint-shell", "lint-neutral"],
  },
  {
    id: "template",
    title: "Change a repository template",
    when: "Every product repository should get a new rule, file or hook.",
    touch: ["templates/repo/", "skills/git-hooks/templates/.githooks (for hooks)"],
    steps: [
      <>
        Edit under <code>templates/repo/</code>. <code>AGENTS.md</code>, <code>CLAUDE.md</code> and the unscoped rules are paid for in every session;{" "}
        <code>lint-budget</code> holds them to their byte budgets. Prefer a rule with <code>paths:</code>.
      </>,
      <>
        A git hook lives twice: <code>templates/repo/.githooks</code> and <code>skills/git-hooks/templates/.githooks</code>. <code>lint-skills</code> fails
        when they differ, so copy the change to both.
      </>,
      <>
        A new document template must say what goes in each section and what good looks like, or <code>lint-templates</code> fails.
      </>,
      <>
        Existing repositories get the change through <S name="onboard-repo" />: the new file is added, a changed one arrives as <code>.bearing-new</code>.
      </>,
    ],
    gates: ["lint-budget", "lint-templates", "lint-skills", "test (scaffold_each_stack, adopt_idempotent, githooks_*)"],
  },
  {
    id: "docs",
    title: "Change the handbook or this guide",
    when: "A stage's main skill changes, a flow changes, or a chapter here is wrong.",
    touch: ["bin/gen-guide.py", "docs/flows.json", "docs/comparisons.json", "site/src/", "bin/gen-devguide.py", "devguide/src/"],
    steps: [
      <>
        Data comes from generators; never edit <code>site/src/data/handbook.json</code>, <code>docs/SKILLS.md</code>, <code>docs/WORKFLOW.md</code> or{" "}
        <code>devguide/src/data/internals.json</code> by hand. Change the source and run <code>make docs</code>.
      </>,
      <>
        The prose of this guide is in <code>devguide/src/pages/</code>. When a chapter quotes behaviour, re-record the replay it shows with{" "}
        <code>python3 devguide/scripts/record.py &lt;session&gt;</code>.
      </>,
      <>
        <code>make site</code> and <code>make devguide</code> build both; <code>make wiki</code> exports the docs where the git host has no Pages.
      </>,
    ],
    gates: ["lint-docs", "lint-prose", "test (deterministic)"],
  },
];

function Recipes() {
  const [id, setId] = useState(RECIPES[0].id);
  const r = RECIPES.find((x) => x.id === id)!;
  return (
    <div className="recipes wide">
      <div className="rc-tabs" role="tablist" aria-label="Recipes">
        {RECIPES.map((x) => (
          <button key={x.id} id={x.id} type="button" role="tab" aria-selected={x.id === id} onClick={() => setId(x.id)}>
            {x.title}
          </button>
        ))}
      </div>
      <div className="rc-body panel" role="tabpanel" key={id}>
        <h3>{r.title}</h3>
        <p className="rc-when">{r.when}</p>
        <div className="rc-cols">
          <ol className="steps">
            {r.steps.map((s, i) => (
              <li key={i}>{s}</li>
            ))}
          </ol>
          <div className="rc-side">
            <p className="tk-label">Files you touch</p>
            <ul>
              {r.touch.map((t) => (
                <li key={t}>
                  <code>{t}</code>
                </li>
              ))}
            </ul>
            <p className="tk-label">Gates that will hold you to it</p>
            <div className="chips">
              {r.gates.map((g) => (
                <span key={g} className="chip brass">
                  {g}
                </span>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export function Change() {
  return (
    <Page
      title="Changing Bearing"
      lede="The kit is built to be changed by the same workflow it gives everyone else: a task branch, the smallest change, the gate before every commit, and you pushing. These are the recipes, each with the files it touches and the gates that will catch a mistake."
      toc={[
        { id: "loop", label: "The loop for any change" },
        { id: "recipes", label: "Recipes" },
        { id: "where", label: "Where does this change go?" },
        { id: "traps", label: "Traps" },
      ]}
      sources={["CONTRIBUTING.md", "skills/new-skill/SKILL.md", "Makefile"]}
    >
      <H2 id="loop">The loop for any change</H2>
      <Code>{`git switch -c feat/<Name>               # or fix/, chore/, docs/ (feat/DevGuide)
# edit; the edit hook lints each file as you go
make check-file FILE=<path>             # what the hook ran, by hand
make check                              # the gate, about three minutes
make docs                               # when skills, flows or docs sources changed
make harness-eval ONLY=<scenario>       # when a hook or the guard changed
# CHANGELOG.md: a line under [Unreleased]
git commit -m "feat(guard): refuse helm rollback"
# you push and open the merge request`}</Code>
      <p>
        Working on the kit inside Claude Code, the kit's own guard and hooks are active, so the agent cannot push your branch either. That is the point: it
        prepares, you ship.
      </p>

      <H2 id="recipes">Recipes</H2>
      <Recipes />

      <H2 id="where">Where does this change go?</H2>
      <div className="tablewrap">
        <table>
          <thead>
            <tr>
              <th>You want</th>
              <th>Change</th>
              <th>Not</th>
            </tr>
          </thead>
          <tbody>
            <tr><td>The agent to never do X</td><td>a guard rule, a settings deny entry, and a git hook if a person should not either</td><td>a sentence in a skill</td></tr>
            <tr><td>The agent to do a step better</td><td>that skill's Steps and Gotchas</td><td>AGENTS.md, which every session pays for</td></tr>
            <tr><td>Every repository to follow a rule</td><td>templates/repo/.claude/rules/ with paths:</td><td>a skill nobody triggers</td></tr>
            <tr><td>A check the model must not eyeball</td><td>a script in skills/&lt;name&gt;/scripts/ that prints a count</td><td>"verify that..." in prose</td></tr>
            <tr><td>A company, host or tracker detail</td><td>bearing.env, NOTICE.md, or a separate plugin with its own prefix</td><td>anything under skills/ (lint-neutral)</td></tr>
            <tr><td>A different main skill for a stage</td><td>STAGES in bin/gen-guide.py, then make docs</td><td>docs/WORKFLOW.md by hand</td></tr>
          </tbody>
        </table>
      </div>

      <H2 id="traps">Traps</H2>
      <ul>
        <li>
          <strong>Your edit is not what runs.</strong> The installed plugin is a cached copy under its version. Reinstall, bump <code>VERSION</code>, or test
          with <code>--plugin-dir</code>.
        </li>
        <li>
          <strong>Writing about blocked commands from Bash.</strong> The installed guard reads every Bash command, heredoc bodies fed to a shell included, so a
          test or doc that spells out a push is refused. Assemble the words at run time, as the tests do, or write the file with an editor.
        </li>
        <li>
          <strong>bash 3.2.</strong> No associative arrays, no <code>mapfile</code>, no <code>${"${x,,}"}</code>, no <code>readarray</code>; BSD sed and stat
          on a Mac. <code>kit:bash32</code> catches most of it; <code>shellcheck</code> the rest.
        </li>
        <li>
          <strong>A skill that depends on another.</strong> It will be run alone. Give every input a fallback.
        </li>
        <li>
          <strong>A gate that prints nothing.</strong> Print the count; fail on zero. <code>gate_selfaudit.sh</code> will find it otherwise.
        </li>
        <li>
          <strong>Em dashes.</strong> In any tracked file, <code>lint-prose</code> fails. Rewrite the sentence rather than swapping the character.
        </li>
      </ul>
    </Page>
  );
}

const RELEASE: Frame[] = [
  { title: "Collapse Unreleased", where: "CHANGELOG.md", body: <p>Move the Unreleased entries under a new version heading with the date, grouped Added, Changed, Fixed, with a one-paragraph summary on top.</p> },
  { title: "Bump VERSION", where: "VERSION, .claude-plugin/plugin.json, .claude-plugin/marketplace.json (twice)", body: <p>Four places hold the version. <code>make lint-version</code> fails until all four match. A new version is also what makes installed machines refresh their cached copy.</p> },
  { title: "Regenerate", where: "make docs", body: <p>The handbook data, docs/SKILLS.md, docs/WORKFLOW.md, the repository skills maps and this guide's data carry the version. Commit them.</p> },
  { title: "Validate locally", where: "make validate, make check, make harness-eval", body: <p>CI cannot run <code>claude plugin validate --strict</code>, so you do. Run the harness eval if any hook or the guard changed since the last release.</p> },
  { title: "Merge", where: "the merge request", body: <p>The pipeline runs kit:check, kit:bash32, every scaffold job and the site builds. On main, the pages and Vercel jobs publish the handbook and this guide.</p> },
  { title: "Tag and push", where: "your terminal", body: <p>A person tags: <code>git tag -a vX.Y.Z -m "bearing X.Y.Z"</code>, then pushes main with tags. The kit never does this for you.</p> },
  { title: "Roll out", where: "upgrade-tools on each machine", body: <p><S name="upgrade-tools" /> updates every installed source with versions before and after, and reruns the doctor.</p> },
];

export function Release() {
  return (
    <Page
      title="Releasing"
      lede={`Bearing is at ${data.version}. A release is seven steps, and the gates make it hard to get one wrong.`}
      toc={[
        { id: "steps", label: "The seven steps" },
        { id: "sites", label: "Publishing the two sites" },
        { id: "history", label: "Versions so far" },
      ]}
      sources={["CHANGELOG.md", "VERSION", ".claude-plugin/plugin.json", ".gitlab-ci.yml"]}
    >
      <H2 id="steps">The seven steps</H2>
      <Stepper label="Releasing Bearing" frames={RELEASE} interval={3000} />

      <H2 id="sites">Publishing the two sites</H2>
      <p>
        Two Vite sites live in the repository, each built from generated data and each deployed as static files: <code>site/</code> is the handbook (how to use
        Bearing) and <code>devguide/</code> is this guide (how Bearing works).
      </p>
      <Code cap="build them locally">{`make site        # site/dist
make devguide    # devguide/dist`}</Code>
      <p>
        On main, the <code>handbook:vercel</code> and <code>devguide:vercel</code> jobs deploy each to its own Vercel project when the project's variables are
        set as masked CI/CD variables: <code>VERCEL_TOKEN</code> and <code>VERCEL_ORG_ID</code> shared, and <code>VERCEL_PROJECT_ID</code> and{" "}
        <code>VERCEL_DEVGUIDE_PROJECT_ID</code> for each site. Both are public by link and never indexed: a robots.txt, a noindex meta tag and an{" "}
        <code>X-Robots-Tag</code> header.
      </p>
      <Note title="Deploying by hand">
        <p>
          From <code>devguide/dist</code> after <code>make devguide</code>: <code>npx vercel@59.26.0 deploy --prod</code>. The <code>vercel.json</code> copied
          into dist tells Vercel to serve the folder as it is, with every path rewritten to the app.
        </p>
      </Note>

      <H2 id="history">Versions so far</H2>
      <div className="history">
        {data.changelog
          .filter((c) => c.version !== "Unreleased")
          .map((c) => (
            <div key={c.version} className="hist">
              <div className="hist-v">
                <b>{c.version}</b>
                <small>{c.date}</small>
              </div>
              <div>
                <p>{c.summary}</p>
                <div className="chips">
                  {c.groups.map((g) => (
                    <span key={g} className="chip">
                      {g}
                    </span>
                  ))}
                  <span className="chip">{c.entries} entries</span>
                </div>
              </div>
            </div>
          ))}
      </div>
    </Page>
  );
}
