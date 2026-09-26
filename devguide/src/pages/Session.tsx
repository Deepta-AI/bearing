import { useEffect, useRef } from "react";
import { Link } from "react-router";
import { Stepper, type Frame } from "../components/Stepper";
import { Terminal } from "../components/Terminal";
import { Code, H2, Note, Page, S } from "../components/ui";
import { data } from "../lib/data";

/**
 * One session, event by event. The branch, file names and prompt are an
 * example; every line a hook prints is the guard's own wording (plugins/bearing/bin/brg-guard
 * session, task-id, check-file, stop-gate, precompact).
 */
type Row = { who: "hook" | "you" | "model" | "tool"; tag?: string; text: string; tone?: "bad" | "good" };
const FILM: { frame: Omit<Frame, "visual">; rows: Row[] }[] = [
  {
    frame: {
      title: "SessionStart",
      where: "plugins/bearing/hooks/scripts/session-start.sh → brg-guard session --id <id> --source startup",
      body: (
        <>
          <p>
            Claude Code starts and hands the hook <code>session_id</code> and <code>source</code>. The guard prints one status line, the first 20 lines of the
            branch's handoff note if <S name="session-handoff" /> left one, and the review checklists for the stacks it detects. Everything printed joins the
            model's context.
          </p>
          <p>
            It also creates <code>.bearing/state/.session-&lt;id&gt;</code>. That empty file's timestamp is the start of this session; the Stop gate will
            only hold the session to files changed after it.
          </p>
        </>
      ),
    },
    rows: [
      { who: "hook", tag: "SessionStart", text: "bearing session: branch=feature/TASK-142-InvoiceExport task=TASK-142 changed_files=0" },
      { who: "hook", tag: "SessionStart", text: "Handoff state from the previous session (.bearing/state/feature_TASK-142-InvoiceExport.md):\n## Next\n- write the CSV encoder in internal/export" },
    ],
  },
  {
    frame: {
      title: "UserPromptSubmit",
      where: "plugins/bearing/hooks/scripts/inject-task-id.sh → brg-guard task-id \"<prompt>\"",
      body: (
        <p>
          You ask for the encoder. The branch carries <code>TASK-142</code> and the prompt does not, so the guard adds one line. It never blocks; when the prompt
          already names the id, or the branch has none, it prints nothing.
        </p>
      ),
    },
    rows: [
      { who: "you", text: "Write the CSV encoder for invoices, test first." },
      { who: "hook", tag: "UserPromptSubmit", text: "Task: TASK-142 (from branch feature/TASK-142-InvoiceExport). Use it in commit messages as [TASK-142]." },
    ],
  },
  {
    frame: {
      title: "PreToolUse, allowed",
      where: "plugins/bearing/hooks/scripts/block-publish.sh → brg-guard command \"<command>\"",
      body: (
        <p>
          Before every Bash call the guard reads the command. <code>go test ./internal/export/...</code> matches no rule, so the guard exits 0, logs{" "}
          <code>command allowed</code> with its time to <code>.bearing/state/gates.log</code>, and the command runs. The model never sees the hook.
        </p>
      ),
    },
    rows: [
      { who: "model", text: "Bash: go test ./internal/export/..." },
      { who: "tool", text: "--- FAIL: TestEncodeInvoice (0.00s)\n    csv_test.go:18: undefined: Encode", tone: "bad" },
    ],
  },
  {
    frame: {
      title: "PostToolUse, a problem",
      where: "plugins/bearing/hooks/scripts/format-file.sh → brg-guard format, then brg-guard check-file",
      body: (
        <>
          <p>
            The model writes <code>csv.go</code>. The hook runs <code>gofmt -w</code> on it (a note to stderr, never a block), then lints that one file. This
            Makefile has no <code>check-file</code> target, so the guard picks by extension: <code>go vet</code> on the package, capped at 25 seconds.
          </p>
          <p>
            vet finds a problem, the guard exits 2, and <code>block_or_print</code> in <code>lib.sh</code> turns that into <code>{'{"decision": "block"}'}</code>{" "}
            with the output as the reason. The edit already happened; the block sends the model back to fix it now.
          </p>
        </>
      ),
    },
    rows: [
      { who: "model", text: "Write: internal/export/csv.go" },
      { who: "hook", tag: "PostToolUse", text: "bearing check: go vet found problems in internal/export/csv.go. Fix them before moving on:\ninternal/export/csv.go:27:3: fmt.Sprintf format %d has arg total of wrong type string", tone: "bad" },
      { who: "model", text: "Edit: internal/export/csv.go (use %s)" },
      { who: "hook", tag: "PostToolUse", text: "(clean: nothing printed, check-file clean logged)", tone: "good" },
    ],
  },
  {
    frame: {
      title: "PreToolUse, refused",
      where: "brg-guard command → exit 2",
      body: (
        <p>
          The tests pass and the model, trying to be helpful, pushes. The settings deny list matches <code>git push</code> by its prefix; the guard also catches
          the forms a prefix cannot see, like <code>env GIT_TRACE=1 git push</code> or <code>make test && git push</code>. The reason goes back to the model,
          which is told to print the command for you instead.
        </p>
      ),
    },
    rows: [
      { who: "model", text: "Bash: go test ./... && git push -u origin feature/TASK-142-InvoiceExport" },
      { who: "hook", tag: "PreToolUse", text: "Bearing blocked 'git push': the engineer pushes, merges and deploys; the agent prepares. Print the command for the engineer instead.", tone: "bad" },
    ],
  },
  {
    frame: {
      title: "PreCompact",
      where: "plugins/bearing/hooks/scripts/precompact.sh → brg-guard precompact <transcript>",
      body: (
        <p>
          The context fills up. Before Claude Code summarises it, the guard writes <code>.bearing/state/&lt;branch&gt;.compact.md</code>: the uncommitted
          changes, the commits on the branch, whether make check passed after the last change, and your last three requests quoted from the transcript (read
          with jq, skipping meta and summary entries).
        </p>
      ),
    },
    rows: [{ who: "hook", tag: "PreCompact", text: "bearing: compaction snapshot written to .bearing/state/feature_TASK-142-InvoiceExport.compact.md" }],
  },
  {
    frame: {
      title: "SessionStart after compaction",
      where: "brg-guard session --source compact",
      body: (
        <p>
          The session resumes with source <code>compact</code>. Same status line, and then the first 60 lines of the snapshot, under the heading "The context
          was just summarised. What stood before it". Your exact words survive the summary. The session mark is kept, so the Stop gate still knows when this
          session began.
        </p>
      ),
    },
    rows: [
      { who: "hook", tag: "SessionStart", text: "The context was just summarised. What stood before it (.bearing/state/feature_TASK-142-InvoiceExport.compact.md):\n## make check\nnot passed since 2 file(s) last changed\n## The user's last requests, verbatim (oldest first)\n- Write the CSV encoder for invoices, test first." },
    ],
  },
  {
    frame: {
      title: "Stop, sent back",
      where: "plugins/bearing/hooks/scripts/stop-summary.sh → brg-guard stop-gate --id <id>",
      body: (
        <>
          <p>
            The model says it is done. The guard lists changed files, keeps those newer than both the session mark and <code>.check-passed</code>, and finds
            two. It exits 2, so the model is sent back once with the reason.
          </p>
          <p>
            It holds a session only when it is fair to: there is a session mark and the Makefile's check target writes <code>.check-passed</code>. Otherwise it
            falls back to <code>brg-guard stop</code>, a reminder that never blocks.
          </p>
        </>
      ),
    },
    rows: [
      { who: "model", text: "The encoder is written and tested." },
      { who: "hook", tag: "Stop", text: "bearing: 2 file(s) changed in this session since make check last passed. Run make check and fix what fails before finishing.", tone: "bad" },
    ],
  },
  {
    frame: {
      title: "Stop, released",
      where: "make check touches .bearing/state/.check-passed",
      body: (
        <p>
          The model runs <code>make check</code>. It passes, and its last line touches <code>.check-passed</code>, so the next Stop finds no fresh files and
          logs <code>stop-gate passed</code>. Had the check failed and the model stopped again, <code>stop_hook_active</code> would be true, the guard would get{" "}
          <code>--active</code>, and it would only remind: a Stop hook that can block forever is worse than none.
        </p>
      ),
    },
    rows: [
      { who: "model", text: "Bash: make check" },
      { who: "tool", text: "check: 9 gates run, 0 skipped", tone: "good" },
      { who: "hook", tag: "Stop", text: "(passed: the session ends)", tone: "good" },
    ],
  },
];

function Transcript({ upto }: { upto: number }) {
  const rows = FILM.slice(0, upto + 1).flatMap((f, fi) => f.rows.map((r) => ({ ...r, fi })));
  const box = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = box.current;
    const cur = el?.querySelector<HTMLElement>(".tr-row.cur");
    if (el && cur) el.scrollTo({ top: cur.offsetTop - 8, behavior: "smooth" });
  }, [upto]);
  return (
    <div className="transcript" aria-label="Session transcript" ref={box}>
      {rows.map((r, i) => (
        <div key={i} className={`tr-row ${r.who} ${r.tone ?? ""} ${r.fi === upto ? "cur" : "old"}`}>
          <span className="tr-who">{r.who === "hook" ? r.tag : r.who === "you" ? "You" : r.who === "model" ? "Claude" : "Output"}</span>
          <span className="tr-text">{r.text}</span>
        </div>
      ))}
    </div>
  );
}

export function Session() {
  const frames: Frame[] = FILM.map((f) => f.frame);
  return (
    <Page
      title="A session, event by event"
      lede="Six hook events, one guard script. Here is a single realistic session on a task branch, with each hook's real wording, followed by how the adapters and the guard divide the work."
      toc={[
        { id: "film", label: "The session" },
        { id: "table", label: "The hook table" },
        { id: "adapters", label: "Anatomy of an adapter" },
        { id: "json", label: "Talking back to Claude Code" },
        { id: "state", label: "The state directory" },
        { id: "telemetry", label: "Gate telemetry" },
      ]}
      sources={["plugins/bearing/hooks/hooks.json", "plugins/bearing/hooks/scripts/lib.sh", "plugins/bearing/hooks/scripts/session-start.sh", "plugins/bearing/hooks/scripts/format-file.sh", "plugins/bearing/hooks/scripts/stop-summary.sh", "plugins/bearing/bin/brg-guard"]}
    >
      <H2 id="film">The session</H2>
      <Stepper label="A session, event by event" frames={frames} visual={(i) => <Transcript upto={i} />} interval={5200} />

      <H2 id="table">The hook table</H2>
      <p>{data.hookDescription}</p>
      <div className="tablewrap">
        <table>
          <thead>
            <tr>
              <th>Event</th>
              <th>Matcher</th>
              <th>Adapter</th>
              <th>Guard</th>
              <th>Timeout</th>
            </tr>
          </thead>
          <tbody>
            {data.hooks.map((h) => (
              <tr key={h.event}>
                <td>
                  <code>{h.event}</code>
                </td>
                <td>{h.matcher ? <code>{h.matcher}</code> : "every"}</td>
                <td>
                  <S name={h.script} />
                </td>
                <td>{h.guard.map((g) => <code key={g}>{g}</code>)}</td>
                <td>{h.timeout} s</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <H2 id="adapters">Anatomy of an adapter</H2>
      <p>
        Each adapter does three things and nothing else: source <code>lib.sh</code>, pull fields out of the event JSON, and hand them to one guard subcommand.
        The decision logic lives in the guard so that Cursor, Codex, Gemini CLI and the rest can call the same logic through their own adapters (see{" "}
        <Link to="/harnesses">Other harnesses</Link>).
      </p>
      <Code cap="plugins/bearing/hooks/scripts/lib.sh, the part every adapter uses">{`HOOK_JSON="$(cat 2>/dev/null || true)"     # the event, read once

json_field() {                              # json_field tool_input.command
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$HOOK_JSON" | jq -r ".\${path} // empty"
  else
    printf '%s' "__BRG_UNPARSED__"          # the guard refuses this: fail closed
  fi
}`}</Code>
      <Note tone="signal" title="Fail closed, but only where it matters">
        <p>
          Without <code>jq</code>, every field reads as the sentinel <code>__BRG_UNPARSED__</code>. The <code>command</code> subcommand refuses it, because a
          command the guard cannot read must not run. The hint subcommands (session, task-id, format, stop) see the sentinel and do nothing, because
          refusing to print a hint would only break the session.
        </p>
      </Note>
      <Terminal id="hooks" height={250} />

      <H2 id="json">Talking back to Claude Code</H2>
      <p>A hook has three ways to be heard, and the kit uses each on purpose:</p>
      <ul>
        <li>
          <strong>Exit 2 with a message on stderr</strong> (PreToolUse): the tool call is cancelled and the message goes to the model.
        </li>
        <li>
          <strong>Exit 0 with <code>{'{"decision": "block", "reason": ...}'}</code> as all of stdout</strong> (PostToolUse, Stop): the model is sent back with
          the reason. <code>block_or_print</code> builds it with <code>jq -n</code>.
        </li>
        <li>
          <strong>Exit 0 with plain stdout</strong> (SessionStart, UserPromptSubmit): the text is added to the context.
        </li>
      </ul>
      <Note title="The trap the harness eval found">
        <p>
          The JSON must be all of stdout. The first live run of the edit hook failed because the formatter's note ("bearing format: gofmt formatted csv.go")
          was printed to stdout before the JSON, and Claude Code read the whole thing as text. That is why <code>format-file.sh</code> sends the format step to
          stderr.
        </p>
      </Note>

      <H2 id="state">The state directory</H2>
      <p>
        Everything the hooks remember lives under <code>.bearing/state/</code> in the product repository, which the template's <code>.gitignore</code>{" "}
        excludes. <S name="brg-state-path" /> computes the per-branch file name.
      </p>
      <div className="tablewrap">
        <table>
          <thead>
            <tr>
              <th>File</th>
              <th>Written by</th>
              <th>Read by</th>
            </tr>
          </thead>
          <tbody>
            <tr><td><code>.session-&lt;id&gt;</code></td><td>session (once per session; older than 7 days removed)</td><td>stop-gate</td></tr>
            <tr><td><code>.check-passed</code></td><td>the Makefile's check target, on success</td><td>stop-gate, stop, precompact, brg-autopilot</td></tr>
            <tr><td><code>&lt;branch&gt;.md</code></td><td><S name="start-task" />, <S name="session-handoff" /></td><td>session (first 20 lines)</td></tr>
            <tr><td><code>&lt;branch&gt;.compact.md</code></td><td>precompact</td><td>session after compaction (first 60 lines)</td></tr>
            <tr><td><code>gates.log</code></td><td>every gate decision</td><td><code>brg-guard stats</code></td></tr>
            <tr><td><code>autopilot.json</code></td><td><S name="brg-autopilot" /></td><td>brg-autopilot, the autopilot skill</td></tr>
          </tbody>
        </table>
      </div>
      <p>
        Branch names become file names by replacing <code>/</code> with <code>_</code>, so <code>feature/TASK-142-InvoiceExport</code> is{" "}
        <code>feature_TASK-142-InvoiceExport.md</code>.
      </p>

      <H2 id="telemetry">Gate telemetry</H2>
      <p>
        Every decision appends one tab-separated line to <code>gates.log</code>: the time, the gate, the outcome, the milliseconds it took and a short label.
        The log rotates to <code>gates.log.1</code> at 512 KB. <code>BEARING_NO_GATE_LOG=1</code> turns it off. <code>brg-guard stats</code> summarises it:
      </p>
      <Code cap="brg-guard stats, the shape of its output">{`brg-guard stats: 412 gate decisions, 2026-09-24T09:12:03 to 2026-09-25T17:40:51
  check-file clean                   88  avg   910 ms  max   4210 ms
  command allowed                   301  avg    21 ms  max    380 ms
  command refused                     9  avg    18 ms  max     25 ms
  stop-gate blocked                   3  avg    40 ms  max     61 ms
  stop-gate passed                   11  avg    35 ms  max     52 ms
  most refused:
       6  git push
       3  git commit --amend`}</Code>
      <p>
        The counts in this sample are illustrative; the columns are the real ones. Use it to answer "is the guard slowing us down" and "which rule do agents
        hit most" before changing either.
      </p>
    </Page>
  );
}
