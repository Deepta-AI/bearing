import { Link } from "react-router";
import { Stepper, type Frame } from "../components/Stepper";
import { Terminal } from "../components/Terminal";
import { Code, Defs, H2, Note, Page, S } from "../components/ui";
import { data } from "../lib/data";

const PH = [
  ["__REPO_NAME__", "InvoiceService"],
  ["__REPO_SLUG__", "invoice-service"],
  ["__MODULE__", "example.com/invoice-service"],
  ["__STACK__", "Go 1.26 + net/http + pgx + sqlc + goose ..."],
  ["__TRACKER__", "none"],
  ["__KIT_REMOTE__", "<the kit's git remote>"],
];

function Layers({ i }: { i: number }) {
  const go = data.stacks.find((s) => s.id === "go-api");
  const repoFiles = data.templates.filter((t) => t.path.startsWith("repo/")).length;
  const stackFiles = go ? go.files.filter((f) => !f.startsWith("skeleton/") && f !== "stack.json").length : 0;
  const skel = go ? go.files.filter((f) => f.startsWith("skeleton/")).length : 0;
  const L = [
    { cls: "l1", b: "plugins/bearing/templates/repo/", s: `${repoFiles} shared files: AGENTS.md, settings, rules, git hooks, docs`, at: 1 },
    { cls: "l2", b: "plugins/bearing-backend/skills/go/templates/", s: `${stackFiles} stack files: Makefile, CI, Dockerfile, linters`, at: 2 },
    { cls: "l3", b: "plugins/bearing-backend/skills/go/templates/skeleton/", s: `${skel} files of working code with tests`, at: 3 },
    { cls: "cut", b: "host filter: gitlab", s: ".github/ removed; .gitlab-ci.yml and .gitlab/ kept", at: 4 },
  ];
  if (i >= 5)
    return (
      <div className="morph" aria-label="Placeholders filled">
        {PH.map(([k, v]) => (
          <div key={k}>
            <span className="ph">{k}</span> → <span className="val">{v}</span>
          </div>
        ))}
        {i >= 6 && <div className="val">lockfile: created by go mod tidy && go -C tools mod tidy</div>}
        {i >= 7 && <div className="val">git init -b main; core.hooksPath=.githooks</div>}
        {i >= 8 && <div className="val">brg-scaffold: 64 files written ... 0 files with unfilled placeholders</div>}
      </div>
    );
  return (
    <div className="layers" aria-hidden="true">
      <div className="layer" style={{ top: 240, borderStyle: "dashed", background: "var(--paper-2)" }}>
        <b>InvoiceService/</b>
        <span>an empty directory (or one holding only .bearing/)</span>
      </div>
      {L.map((l, n) => (
        <div key={l.b} className={`layer ${l.cls} ${i >= l.at ? "" : "waiting"}`} style={{ top: i >= l.at ? 240 - (n + 1) * 56 : 0 }}>
          <b>{l.b}</b>
          <span>{l.s}</span>
        </div>
      ))}
    </div>
  );
}

const FRAMES: Frame[] = [
  {
    title: "Resolve",
    where: "brg-scaffold go-api InvoiceService --host gitlab",
    body: (
      <p>
        Flags win, then <code>bearing.env</code>, then defaults. The stack is found by grepping every <code>plugins/*/skills/*/templates*/stack.json</code> for{" "}
        <code>"id": "go-api"</code>; its required keys (id, type, stack, databases, entrypoint, rules_file) are checked. The target must be empty, or hold only{" "}
        <code>.bearing/</code>, because autopilot starts its run state before the repository exists.
      </p>
    ),
  },
  {
    title: "Shared files",
    where: "cp -R plugins/bearing/templates/repo/. <dir>/",
    body: <p>The standard every repository commits, whatever its stack: AGENTS.md, CLAUDE.md, the Claude settings and rules, the three git hooks, the MR and issue templates for both hosts, the docs templates, CODEOWNERS.</p>,
  },
  {
    title: "Stack files",
    where: "every file in the stack's templates/ except skeleton/ and stack.json",
    body: (
      <p>
        The build: Makefile, both CI files, Dockerfile, compose, linters. A <code>.gitignore.append</code> is concatenated rather than copied, so the stack's
        ignores add to the shared ones.
      </p>
    ),
  },
  {
    title: "Skeleton",
    where: "cp -R templates/skeleton/. <dir>/",
    body: <p>A small service that already passes its own gate: config, health, middleware, a store with a migration, telemetry, and tests for each. A new repository starts green, so the first red is yours.</p>,
  },
  {
    title: "Host filter and rules",
    where: "--host gitlab | github | both",
    body: (
      <p>
        One host keeps only its CI and templates. Then the stack's <code>references/rules.md</code> is copied to <code>.claude/rules/&lt;rules_file&gt;</code>{" "}
        (go.md here), and <code>.gitignore.append</code> is merged into <code>.gitignore</code>.
      </p>
    ),
  },
  {
    title: "Placeholders",
    where: "sed over every text file, then file and directory names, deepest first",
    body: (
      <p>
        Twelve tokens are replaced in every text file (binary files are skipped with <code>grep -I</code>); values are escaped for sed. Then paths containing{" "}
        <code>__REPO_NAME__</code> or <code>__REPO_SLUG__</code> are renamed, children before parents.
      </p>
    ),
  },
  {
    title: "Lockfile",
    where: "stack.json install, when stack.json tool is on PATH",
    body: (
      <p>
        The stack's install command runs once so the first commit has a lockfile and CI can install frozen. It never fails the scaffold: with the tool missing
        or the install failing, it says so and CI installs unfrozen until you run it.
      </p>
    ),
  },
  {
    title: "Git and hooks",
    where: "git init -b main; chmod +x .githooks/*; git config core.hooksPath .githooks",
    body: <p>The hooks are live from the first commit on this clone. A teammate's clone gets them from <code>make setup</code>, which runs <code>.githooks/install.sh</code>.</p>,
  },
  {
    title: "Count and check",
    where: "the last line",
    body: (
      <p>
        It counts files written and paths renamed, then greps for any <code>__NAME__</code> left unfilled (except <code>__BACKEND__</code>, a deliberate marker
        that <S name="tech-decision" /> fills when the cloud is chosen), skipping dependency and build folders. Zero files written is a failure. <code>--check</code>{" "}
        runs <code>make check</code> in the result.
      </p>
    ),
  },
];

export function Scaffold() {
  return (
    <Page
      title="Scaffolding a repository"
      lede={`brg-scaffold turns a stack id and a name into a repository that passes its own gate before anyone writes a line. It is ${data.scripts.find((x) => x.name === "brg-scaffold")?.lines} lines of bash, and every step below is one of its numbered steps.`}
      toc={[
        { id: "watch", label: "Watch it build one" },
        { id: "steps", label: "Step by step" },
        { id: "stacks", label: `The ${data.stacks.length} stacks` },
        { id: "stackjson", label: "stack.json" },
        { id: "tokens", label: "The placeholders" },
        { id: "result", label: "What you get" },
        { id: "hooks", label: "The git hooks" },
        { id: "settings", label: "The permission model" },
        { id: "tested", label: "How it is tested" },
      ]}
      sources={["plugins/bearing/bin/brg-scaffold", "plugins/bearing/templates/repo/", "plugins/bearing/skills/new-repo/SKILL.md", "tests/integration/scaffold_each_stack.sh"]}
    >
      <H2 id="watch">Watch it build one</H2>
      <Terminal id="scaffold" height={380} />

      <H2 id="steps">Step by step</H2>
      <Stepper label="brg-scaffold, step by step" frames={FRAMES} visual={(i) => <Layers i={i} />} interval={3400} />
      <p>
        You rarely call the script yourself: <S name="new-repo" /> asks for what it cannot infer (stack, name, host, tracker, lead), runs{" "}
        <S name="brg-scaffold" />, then <code>make setup</code> and <code>make check</code>. It never commits: it prints the first commit command for you, and reports the remote project and CI variables under Not done.
      </p>

      <H2 id="stacks">The {data.stacks.length} stacks</H2>
      <p>
        A stack is not registered anywhere: a folder <code>plugins/&lt;plugin&gt;/skills/&lt;lane&gt;/templates*/</code> holding a <code>stack.json</code> is a stack. Two lanes
        ship a second variant in <code>templates-cli/</code>.
      </p>
      <div className="tablewrap">
        <table>
          <thead>
            <tr>
              <th>id</th>
              <th>Type</th>
              <th>Stack</th>
              <th>Files</th>
              <th>Lockfile by</th>
            </tr>
          </thead>
          <tbody>
            {data.stacks.map((s) => (
              <tr key={s.id}>
                <td>
                  <code>{s.id}</code>
                  <br />
                  <Link to={`/skills/${s.skill}`} className="sub">
                    {s.dir.replace(/^plugins\/[^/]+\/skills\//, "")}
                  </Link>
                </td>
                <td>{s.type}</td>
                <td>{s.stack}</td>
                <td className="num">{s.files.length}</td>
                <td>{s.install ? <code>{s.install}</code> : "n/a"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <H2 id="stackjson">stack.json</H2>
      <Code cap="plugins/bearing-apps/skills/react/templates/stack.json">{`{
  "id": "react-web",               the name brg-scaffold and brg-adopt take
  "display": "React web app",
  "type": "Client/Web",            fills __REPO_TYPE__ in CLAUDE.md
  "stack": "React 19 + TypeScript + Vite + ...",   fills __STACK__
  "databases": "none (talks to the API)",          fills __DATABASES__
  "entrypoint": "src/main.tsx",                    fills __ENTRYPOINT__
  "rules_file": "react.md",        references/rules.md is copied to .claude/rules/react.md
  "check_command": "make check",
  "install": "pnpm install",       run once for the lockfile
  "tool": "pnpm"                   ...only when this is on PATH
}`}</Code>
      <p>
        <code>tests/unit/stack_json.sh</code> validates every stack.json, and <code>lint-json</code> parses them.
      </p>

      <H2 id="tokens">The placeholders</H2>
      <Defs
        rows={[
          ["__REPO_NAME__", "the PascalName you gave"],
          ["__REPO_SLUG__", "its kebab-case form, also the default directory"],
          ["__MODULE__", "--module, else example.com/<slug> (Go)"],
          ["__STACK__, __REPO_TYPE__, __DATABASES__, __ENTRYPOINT__", "from stack.json (--databases overrides)"],
          ["__TRACKER__", "PREFIX-### from --tracker or BEARING_TASK_ID_PREFIX, else the tracker name or none"],
          ["__LEAD__, __TEAM_GROUP__", "--lead and --group, without the @; CODEOWNERS uses them"],
          ["__ORG_ID__", "--org or BEARING_ORG_ID, else com.example (mobile bundle ids)"],
          ["__KIT_REMOTE__", "--kit-remote or BEARING_KIT_REMOTE, else the kit's own origin; settings.json offers it as the marketplace"],
        ]}
      />

      <H2 id="result">What you get</H2>
      <p>The recording above, as a map. Everything outside cmd/, internal/ and db/ is the standard; those three are the skeleton.</p>
      <div className="tree">
        {[
          ["AGENTS.md", "the standard for every agent, loaded every session"],
          ["CLAUDE.md", "@AGENTS.md, then the repository snapshot"],
          [".claude/settings.json", `${data.settings.allow} allow, ${data.settings.ask} ask, ${data.settings.deny} deny; sandbox; the Bearing marketplace`],
          [".claude/rules/", `${data.settings.rules.length} shared rules + go.md; only ${data.settings.unscopedRules.join(", ")} loads without a path match`],
          [".githooks/", "commit-msg, pre-commit, pre-push, lib.sh, install.sh"],
          [".github/", "GitHub: the workflow and the pull request template"],
          [".gitlab-ci.yml, .gitlab/", "GitLab: the pipeline and the merge request and issue templates (both hosts by default; BEARING_GIT_HOST picks one)"],
          ["Makefile", "help, setup, dev, check, fix, test, check-file; check touches .bearing/state/.check-passed"],
          ["docs/", "adr/, design/, runbooks/, postmortems/, security/, analytics/, templates/"],
          ["cmd/, internal/, db/", "the skeleton service and its tests"],
          ["go.mod, go.sum, tools/go.mod", "the module, with tools pinned in their own module"],
        ].map(([p, n]) => (
          <div className="row" key={p}>
            <span className={p.endsWith("/") ? "dir" : undefined}>{p}</span>
            <span>{n}</span>
          </div>
        ))}
      </div>

      <H2 id="hooks">The git hooks</H2>
      <p>They hold whoever commits: you, a teammate without Bearing, or an agent on any harness.</p>
      <div className="cols">
        <div className="card">
          <h4>commit-msg</h4>
          <p>Conventional Commit subject within 72 characters; the task id from the branch at the end in brackets; no AI attribution trailer; no em dash.</p>
        </div>
        <div className="card">
          <h4>pre-commit</h4>
          <p>Fails on zero staged files; refuses secrets by name (.env, keys, service accounts) and by pattern in the diff; refuses notes files at the root; checks formatting of staged files with the stack's formatters.</p>
        </div>
        <div className="card">
          <h4>pre-push</h4>
          <p>Counts the commits and refs (zero is a failure); a person confirms at a terminal within 60 seconds; the branch name convention; no push to main or develop; then make check.</p>
        </div>
      </div>

      <H2 id="settings">The permission model</H2>
      <p>
        <code>defaultMode</code> is <code>{data.settings.defaultMode}</code>: edits go through, commands follow the lists.
      </p>
      <ul>
        <li>
          <strong>allow ({data.settings.allow})</strong>: reading, the make targets, git reads and local commits, the stack toolchains' build and test commands.
        </li>
        <li>
          <strong>ask ({data.settings.ask})</strong>: changes you should see first, such as adding a dependency or dropping a local database. For example{" "}
          {data.settings.askSamples.slice(0, 4).map((a, i) => (
            <span key={a}>
              {i ? ", " : ""}
              <code>{a}</code>
            </span>
          ))}
          .
        </li>
        <li>
          <strong>deny ({data.settings.deny})</strong>: push, history rewrites, merge and release commands for both hosts, publishing, deploys, cloud CLIs,
          destructive system commands, and reading secrets.
        </li>
        <li>
          <strong>sandbox</strong>: {data.settings.domains} network domains (package registries and vulnerability databases); writes allowed to the package
          caches ({data.settings.allowWrite.join(", ")}); reads denied to {data.settings.denyRead.join(", ")}; writes denied to{" "}
          {data.settings.denyWrite.join(", ")}.
        </li>
      </ul>
      <Note title="Why the caches are writable">
        <p>
          The first sandboxed template broke every <code>npm</code>, <code>pnpm</code>, <code>uv</code> and <code>go</code> install, because their caches live
          outside the repository. <code>make harness-eval</code> has a sandbox scenario that proves installs work and <code>.env</code> stays unreadable.
        </p>
      </Note>

      <H2 id="tested">How it is tested</H2>
      <ul>
        <li>
          <code>tests/integration/scaffold_each_stack.sh</code> scaffolds every stack with <code>--host both</code>, then checks: no unfilled placeholder,
          hooks executable and wired, <code>CLAUDE.md</code> starts with <code>@AGENTS.md</code>, settings parse, <code>make -n check</code> works,{" "}
          <code>.bearing/state</code> and <code>.env</code> ignored. Plus both single-host variants and a tool-free PATH.
        </li>
        <li>
          In CI, one <code>kit:scaffold:&lt;stack&gt;</code> job per stack runs <code>make setup && make check</code> inside the result, in that stack's own
          image. A daily schedule runs them with fresh dependencies, so a bad upstream release fails the next morning rather than in the next new repository.
        </li>
      </ul>
    </Page>
  );
}

function AdoptTree() {
  const rows = [
    { q: "The file is missing", a: "added", tone: "jade", d: "copied in" },
    { q: "The file is identical", a: "kept", tone: "sea", d: "nothing to do" },
    { q: "The file differs", a: "conflict", tone: "brass", d: "the standard's version is written beside it as <file>.bearing-new" },
    { q: ".gitignore", a: "appended", tone: "jade", d: "the Bearing block is appended once" },
    { q: "core.hooksPath is .husky", a: "conflict", tone: "brass", d: "left alone; prints the one line to chain each hook, or the command to switch" },
    { q: "Makefile check lacks the marker", a: "conflict", tone: "brass", d: "Makefile.bearing-new adds one last recipe line to check" },
  ];
  return (
    <div className="adopt-tree wide">
      <div className="at-root">For every file the standard ships</div>
      <div className="at-rows">
        {rows.map((r) => (
          <div key={r.q} className="at-row">
            <span className="at-q">{r.q}</span>
            <span className={`chip ${r.tone}`}>{r.a}</span>
            <span className="at-d">{r.d}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

export function Adopt() {
  return (
    <Page
      title="Adopting a repository"
      lede="brg-adopt brings an existing repository onto the standard without overwriting a single file. Everything it would change becomes a proposal beside the original, and running it twice changes nothing."
      toc={[
        { id: "rule", label: "The one rule" },
        { id: "watch", label: "Watch it, twice" },
        { id: "how", label: "How it decides" },
        { id: "build", label: "Build files are offered, not imposed" },
        { id: "gate", label: "Making the Stop gate block" },
        { id: "skill", label: "The onboard-repo skill" },
      ]}
      sources={["plugins/bearing/bin/brg-adopt", "plugins/bearing/skills/onboard-repo/SKILL.md", "tests/integration/adopt_idempotent.sh"]}
    >
      <H2 id="rule">The one rule</H2>
      <p>
        Adopt builds the whole desired tree in a temporary staging directory first (shared files, the stack's rules, placeholders filled), and only then walks
        it against the repository. It never edits a file that exists. That is what makes it safe to run on a codebase you did not write.
      </p>

      <H2 id="watch">Watch it, twice</H2>
      <p>
        The first run adds 36 files to a repository that had a package.json and a README. The second finds 34 files in the standard and keeps all 34: the
        Makefile and the GitHub workflow are no longer offered, because the repository now has them.
      </p>
      <Terminal id="adopt" height={360} />

      <H2 id="how">How it decides</H2>
      <AdoptTree />

      <H2 id="build">Build files are offered, not imposed</H2>
      <p>
        A repository that already builds keeps its build. The stack's Makefile is staged only when there is no Makefile; <code>.gitlab-ci.yml</code> only when
        there is none; <code>.github/</code> only when there are no workflows. Everything else in the standard (AGENTS.md, settings, rules, hooks, docs
        templates) is always staged.
      </p>

      <H2 id="gate">Making the Stop gate block</H2>
      <p>
        The Stop hook can only hold a session to <code>make check</code> if the check target records a pass. Every stack template's Makefile does. For a
        repository's own Makefile, adopt finds the single <code>check:</code> rule (not a double-colon rule, not two rules), walks past its prerequisites and
        recipe, and proposes one more recipe line:
      </p>
      <Code cap="Makefile.bearing-new, the added line">{`check: lint test
	golangci-lint run
	go test ./...
	@mkdir -p .bearing/state && touch .bearing/state/.check-passed`}</Code>
      <p>
        Make stops at the first failing line, so the last line only runs when everything before it passed. When the Makefile has no check target, or one adopt
        cannot safely extend, it prints the line for you instead.
      </p>

      <H2 id="skill">The onboard-repo skill</H2>
      <p>
        <S name="onboard-repo" /> wraps the script: it detects the stack from the files present, runs <S name="brg-adopt" />, then walks you through each{" "}
        <code>.bearing-new</code> proposal one at a time and records the snapshot in CLAUDE.md. For a codebase you inherited, the inherited-codebase flow
        continues with <S name="explain-codebase" />, <S name="docs-drift" /> and a characterisation baseline.
      </p>
    </Page>
  );
}
