import { useMemo, useState } from "react";
import { Link } from "react-router";
import { GuardAnatomy } from "../components/GuardAnatomy";
import { Terminal } from "../components/Terminal";
import { Code, Defs, H2, Note, Page, S } from "../components/ui";
import { data } from "../lib/data";

function RuleTable() {
  const [q, setQ] = useState("");
  const tools = useMemo(() => {
    const m = new Map<string, { pattern: string; label: string }[]>();
    for (const r of data.guardRules) {
      if (q && !`${r.tool} ${r.pattern} ${r.label}`.toLowerCase().includes(q.toLowerCase())) continue;
      if (!m.has(r.tool)) m.set(r.tool, []);
      m.get(r.tool)!.push(r);
    }
    return [...m.entries()];
  }, [q]);
  const shown = tools.reduce((a, [, rs]) => a + rs.length, 0);
  return (
    <div className="wide">
      <div className="filters">
        <input type="search" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Filter: push, kubectl, publish" aria-label="Filter rules" />
        <span className="count">
          {shown} of {data.guardRules.length} rules, {tools.length} programs
        </span>
      </div>
      <div className="rulegrid">
        {tools.map(([tool, rows]) => (
          <div className="rulecard" key={tool}>
            <b>{tool}</b>
            {rows.map((r, i) => (
              <div key={i} className="rule">
                <code>{r.pattern || "(any use)"}</code>
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}

export function Guard() {
  const g = data.scripts.find((s) => s.name === "brg-guard")!;
  return (
    <Page
      title="The guard"
      lede={`plugins/bearing/bin/brg-guard is ${g.lines.toLocaleString("en")} lines of bash 3.2 that decide whether a shell command may run. It is the one piece of Bearing that must be right, so it is built to refuse whatever it cannot read.`}
      toc={[
        { id: "walk", label: "Watch it read a command" },
        { id: "pipeline", label: "The pipeline" },
        { id: "patterns", label: "The pattern language" },
        { id: "rules", label: `The ${data.guardRules.length} rules` },
        { id: "hard", label: "The hard cases" },
        { id: "readonly", label: "Read-only mode" },
        { id: "subcommands", label: "Every subcommand" },
        { id: "which", label: "Which wall refused me?" },
      ]}
      sources={["plugins/bearing/bin/brg-guard", "tests/unit/guard_deny_table.sh", "tests/unit/guard_readonly.sh", "tests/unit/guard_latency.sh"]}
    >
      <H2 id="walk">Watch it read a command</H2>
      <p>Pick an example. Each step names the function in the guard that does it; the final verdict and message are what the guard really printed.</p>
      <GuardAnatomy />
      <Terminal id="guard" height={280} title="The same four commands and three more, run against the real guard" />

      <H2 id="pipeline">The pipeline</H2>
      <p>
        <code>guard_command</code> is short. The work is in the scanners it calls, which walk the string byte by byte (with <code>LC_ALL=C</code>) keeping
        track of quotes, so the guard sees the same words the shell will.
      </p>
      <ol className="steps">
        <li>
          <strong>Pre-checks.</strong> Empty, holds the <code>__BRG_UNPARSED__</code> sentinel or another guard marker, over <code>MAX_LEN</code> (16,384
          bytes), or a fork bomb: refused before any parsing.
        </li>
        <li>
          <strong>Heredocs</strong> (<code>strip_data_heredocs</code>). A body fed to <code>cat</code>, <code>tee</code> or a git message (<code>-F -</code>)
          is data and is set aside. A body fed to a shell or an interpreter is code and is checked. An unquoted delimiter means the shell will expand{" "}
          <code>$( )</code> inside the body, so those substitutions are checked too.
        </li>
        <li>
          <strong>Substitutions</strong> (<code>extract_substitutions</code>). Each <code>$( )</code> and backtick pair is checked as a command of its own, then
          replaced by a marker. A program name or verb that comes from a substitution is unreadable.
        </li>
        <li>
          <strong>Segments</strong> (<code>scan_segments</code>). Split on <code>;</code> <code>&amp;</code> <code>|</code> <code>(</code> <code>)</code> and
          newlines. Each segment's tokens go to <code>check_tokens</code>.
        </li>
        <li>
          <strong>Wrappers</strong> (<code>strip_wrappers</code>). env, sudo, command, exec, nohup, setsid, flock, strace, timeout, xargs, parallel and shell
          keywords are removed with their options, matched on the basename so <code>/usr/bin/env</code> counts. <code>NAME=value</code> prefixes are
          remembered; a value that git or a pager would run is itself checked.
        </li>
        <li>
          <strong>Git specifics</strong> (<code>strip_git_options</code>, <code>git_checks</code>). <code>-C dir</code>, <code>-c k=v</code>,{" "}
          <code>--git-dir</code> are removed. Setting an alias or a config that runs code (<code>core.pager</code>, <code>core.sshCommand</code>) is refused, and
          aliases already in the real git config are expanded and checked.
        </li>
        <li>
          <strong>Rules</strong> (<code>match_tool_rules</code>). The tool's rows are tried against the arguments. A shell (<code>bash -c</code>),{" "}
          <code>eval</code>, or <code>python -c</code> is recursed into: its string is checked as a command, and for code, every quoted literal and the
          flattened text are checked.
        </li>
        <li>
          <strong>Verdict.</strong> <code>deny</code> prints the Bearing message and exits 2; <code>refuse</code> prints why the command could not be read and
          exits 2; falling off the end logs <code>allowed</code> and exits 0.
        </li>
      </ol>

      <H2 id="patterns">The pattern language</H2>
      <p>
        One rule per line in <code>verb_rows</code>, as <code>tool|pattern|label</code>. The tool is argv[0] after wrappers and path are removed, and may be a
        glob (<code>mkfs*</code>). The pattern is space-separated tokens matched against the rest:
      </p>
      <Defs
        rows={[
          ["word", "the next positional argument, skipping flags (and one value after a flag); may be a glob such as publish*"],
          ["*", "any positional argument"],
          ["--x, -x", "that flag anywhere, also as --x=value"],
          ["~abc", "one of the letters a, b or c inside a short-flag cluster anywhere: ~f matches -f, -fd, -xf"],
          ["@danger", "an argument that leaves the repository: /, ~, ., .., *, an absolute path, a relative path whose .. climbs out, or a variable"],
          ["@remote", "an argument shaped host:path or user@host:path"],
          ["(empty)", "any use of the tool at all (ssh, dd, shutdown)"],
        ]}
      />
      <Code cap="three rows from verb_rows, read aloud">{`git|clean ~f ~dx|git clean -fdx      git, then clean, then an f and a d or x in some flag cluster
rm|~rR ~f @danger|rm -rf outside...  rm with r and f flags and a path that climbs out of the repo
scp|@remote|scp to a remote          scp with any host:path argument`}</Code>

      <H2 id="rules">The {data.guardRules.length} rules</H2>
      <p>
        Straight from <code>brg-guard --verbs</code> when this site was built. <S name="brg-harness" /> derives the Codex execpolicy, the Gemini exclusions
        and the Zed regexes from the same output, and the handbook states its count. The deny list in <code>plugins/bearing/templates/repo/.claude/settings.json</code> is
        kept by hand beside it, so a new rule usually wants a matching <code>Bash(...)</code> deny entry too.
      </p>
      <RuleTable />

      <H2 id="hard">The hard cases</H2>
      <p>Each of these was a real bypass or a real false refusal at some point; each now has rows in the deny table test.</p>
      <div className="tablewrap">
        <table>
          <thead>
            <tr>
              <th>Command</th>
              <th>Verdict</th>
              <th>Why</th>
            </tr>
          </thead>
          <tbody>
            <tr><td><code>SUB=status; git $SUB</code></td><td className="ok">allowed</td><td>The variable is assigned in the same command, so it is substituted and checked again.</td></tr>
            <tr><td><code>git $SUB origin</code></td><td className="no">refused</td><td>Unknown value in the verb position: fail closed.</td></tr>
            <tr><td><code>git -c alias.p=push p</code></td><td className="no">refused</td><td>Defining an alias inline could rename any verb.</td></tr>
            <tr><td><code>bash -c 'git push'</code></td><td className="no">refused</td><td>The string is recursed into as a command.</td></tr>
            <tr><td><code>cat &lt;&lt;'EOF' &gt; notes.md</code> mentioning a push</td><td className="ok">allowed</td><td>A quoted heredoc fed to cat is data.</td></tr>
            <tr><td><code>git commit -F - &lt;&lt;EOF</code> mentioning a deploy</td><td className="ok">allowed</td><td>A commit message is text, even when it names a blocked verb.</td></tr>
            <tr><td><code>python3 -c "os.system('git push')"</code></td><td className="no">refused</td><td>Code strings: every literal is checked as a command.</td></tr>
            <tr><td><code>helm upgrade --help</code></td><td className="ok">allowed</td><td><code>is_help_only</code>: help for a blocked verb is fine.</td></tr>
            <tr><td><code>rm -rf ./build</code></td><td className="ok">allowed</td><td>Stays inside the repository, so @danger does not match.</td></tr>
            <tr><td>a 17,000-byte command</td><td className="no">refused</td><td>Over 16,384 bytes. Parsing that much in bash 3.2 could outlast the 10 second hook timeout.</td></tr>
          </tbody>
        </table>
      </div>
      <Note title="Speed is part of correctness">
        <p>
          The guard runs before every Bash call, so a slow guard is a tax on all work. <code>tests/unit/guard_latency.sh</code> times an 8,000 byte command
          (about 370 ms when recorded) and checks that an over-limit command is refused in milliseconds. Keep new scanning linear: index into the string,
          never spawn a process per character.
        </p>
      </Note>

      <H2 id="readonly">Read-only mode</H2>
      <p>
        <code>brg-guard readonly "&lt;command&gt;"</code> inverts the logic: instead of a deny list it is an allow list. Every program in the command must be a
        read-only tool: git diff, log, show, status, blame and ls-files; ls, cat, grep, rg, find without <code>-exec</code>, sed without <code>-i</code>, jq,
        and similar. <code>tee</code>, <code>sort -o</code>, awk that writes or pipes to a command, and interpreter one-liners are refused. It exists for
        harnesses and agents that must look but not touch; the kit's own reviewer agents go further and get no shell at all.
      </p>

      <H2 id="subcommands">Every subcommand</H2>
      <div className="tablewrap">
        <table>
          <thead>
            <tr>
              <th>Subcommand</th>
              <th>Called by</th>
              <th>Exit</th>
            </tr>
          </thead>
          <tbody>
            <tr><td><code>command "&lt;cmd&gt;"</code></td><td>PreToolUse (Bash)</td><td>0 run it, 2 refused</td></tr>
            <tr><td><code>readonly "&lt;cmd&gt;"</code></td><td>read-only adapters</td><td>0, 2</td></tr>
            <tr><td><code>format &lt;file&gt;</code></td><td>PostToolUse, first</td><td>always 0</td></tr>
            <tr><td><code>check-file &lt;file&gt;</code></td><td>PostToolUse, second</td><td>0 clean or not checkable, 2 problems</td></tr>
            <tr><td><code>task-id "&lt;prompt&gt;"</code></td><td>UserPromptSubmit</td><td>always 0</td></tr>
            <tr><td><code>session --id --source</code></td><td>SessionStart</td><td>always 0</td></tr>
            <tr><td><code>precompact &lt;transcript&gt;</code></td><td>PreCompact</td><td>always 0</td></tr>
            <tr><td><code>stop-gate --id [--active]</code></td><td>Stop</td><td>0, or 2 once</td></tr>
            <tr><td><code>stop</code></td><td>stop-gate's fallback</td><td>always 0 (a reminder)</td></tr>
            <tr><td><code>stats</code></td><td>you</td><td>0, or 1 with nothing logged</td></tr>
            <tr><td><code>--verbs</code>, <code>--version</code></td><td>generators, <S name="brg-doctor" /></td><td>0</td></tr>
          </tbody>
        </table>
      </div>
      <p>
        The version line reads <code>BEARING_GUARD_VERSION="__VERSION__"</code> in the kit; <S name="brg-harness" /> stamps the real version when it vendors a
        copy into a repository as <code>.bearing/bin/brg-guard</code>, and the doctor compares the two.
      </p>

      <H2 id="which">Which wall refused me?</H2>
      <p>The wording tells you. When a command you expected to run is refused:</p>
      <Defs
        rows={[
          ["Bearing blocked 'x'", "the guard matched a rule. Change the rule in verb_rows, or run the command yourself."],
          ["brg-guard: ... refusing (fail closed)", "the guard could not read the command. Rewrite it without the variable or substitution in the verb."],
          ["Permission denied by settings", "the repository's .claude/settings.json deny or ask list; the harness, not Bearing's code."],
          ["pre-commit: / commit-msg: / pre-push:", "a git hook in .githooks/. It holds for you as well as for the agent."],
          ["sandbox: operation not permitted", "the Bash sandbox: a write outside the allowed paths or a host off the network list."],
        ]}
      />
      <p>
        To change what the guard does, see <Link to="/change#guard-rule">Changing Bearing: a guard rule</Link>.
      </p>
    </Page>
  );
}
