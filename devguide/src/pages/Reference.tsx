import { Link } from "react-router";
import { Terminal } from "../components/Terminal";
import { Code, Page } from "../components/ui";
import { recordings } from "../lib/data";

const WHERE: Record<string, [string, string]> = {
  guard: ["/guard", "The guard"],
  hooks: ["/session#adapters", "A session, event by event"],
  scaffold: ["/scaffold", "Scaffolding a repository"],
  adopt: ["/adopt", "Adopting a repository"],
  autopilot: ["/autopilot", "Autopilot and the task loop"],
  check: ["/gates", "Gates, tests and CI"],
  tracker: ["/trackers", "Trackers"],
};

export function Replays() {
  return (
    <Page
      full
      title="Terminal replays"
      lede="Every recording on this site, in one place. They are real runs of the kit's own commands against this checkout, captured line by line with their timing, with home and scratch paths rewritten."
    >
      <Code cap="record them again after a change they show">{`python3 devguide/scripts/record.py            # every session
python3 devguide/scripts/record.py scaffold   # one`}</Code>
      {Object.entries(recordings).map(([k, r]) => (
        <section key={k}>
          <h2 className="grouphead">
            {r.title}
            {WHERE[k] && (
              <small>
                {" "}
                <Link to={WHERE[k][0]}>in {WHERE[k][1]}</Link>
              </small>
            )}
          </h2>
          <Terminal id={k} height={k === "check" ? 460 : 320} />
        </section>
      ))}
    </Page>
  );
}

const TERMS: [string, string][] = [
  ["adapter", "A few lines of shell that turn one harness event's JSON into arguments for a brg-guard subcommand, and its answer back into what that harness expects."],
  ["allowed-tools", "The tools a skill may use without asking while it runs. Least privilege; lint-tools checks that every command the skill names is covered."],
  ["auto skill", "A skill the model may start when your words match its description; every Bearing skill is one, and each can also be typed as /bearing:<name>. Its description is in every session's context."],
  [".bearing/", "Per-repository state. state/ is ignored by git and holds the session mark, the check marker, handoff notes, snapshots, gates.log and autopilot.json. bin/ holds a vendored guard for other harnesses."],
  [".bearing-new", "A proposal written beside a file that exists with different content. brg-adopt and brg-harness never overwrite."],
  ["bearing.env", "~/.config/bearing/bearing.env, the one per-developer config file: tracker, host, credentials, the kit remote. Mode 600, parsed, never sourced."],
  [".check-passed", "An empty file the Makefile's check target touches on success. The Stop gate, the precompact snapshot and autopilot compare file times against it."],
  ["command skill", "A skill with disable-model-invocation: true. Only a person starts it; the model does not see it listed. Bearing has none, since that would hide the skill from plain requests."],
  ["compaction snapshot", "<branch>.compact.md, written before the context is summarised and printed after, so your last requests survive."],
  ["Decisions first", "A block in a skill that runs tech-decision before writing anything that depends on a choice. Such a skill must grant Skill."],
  ["fail closed", "When the guard cannot read a command (a variable verb, an unparsed hook JSON, an over-long command) it refuses rather than allows."],
  ["gate", "A check that prints what it counted and fails on zero. Every step of make check is one."],
  ["guard", "plugins/bearing/bin/brg-guard, the one script behind every hook on every harness."],
  ["handoff note", ".bearing/state/<branch>.md, written by start-task and session-handoff, printed at the next SessionStart."],
  ["harness", "A coding agent host: Claude Code, Cursor, Codex, Gemini CLI, Copilot, OpenCode, Windsurf, Cline, Zed, Kiro."],
  ["pinned pack", "A third-party skill fetched at a fixed commit by brg-install-packs, with a .bearing-pack provenance file."],
  ["profile", "minimal, standard or full: how much install.sh installs. Also, in autopilot, the product profile (ui, data, api, deploy) that decides which stages apply."],
  ["progress record", "docs/progress/<ID>.md, the committed, shared status of a task, written only through progress.py."],
  ["Proposed", "The status autopilot gives every decision it takes on your behalf. Only a person makes a decision Accepted."],
  ["session mark", ".bearing/state/.session-<id>, created at SessionStart. The Stop gate holds a session only to files changed after it."],
  ["stack", "A folder plugins/<plugin>/skills/<lane>/templates*/ with a stack.json. brg-scaffold and brg-adopt discover stacks by that file."],
  ["Stop gate", "brg-guard stop-gate: sends the model back once when files it changed have not passed make check since."],
  ["tracker none", "Running without a ticket tracker. Read verbs succeed, write verbs exit 3, which callers treat as skipped."],
  ["verb table", "verb_rows in plugins/bearing/bin/brg-guard: tool|pattern|label rows. brg-guard --verbs prints it for the generators."],
];

export function Glossary() {
  return (
    <Page full title="Glossary" lede="The words this guide uses with a specific meaning in Bearing.">
      <dl className="glossary">
        {TERMS.map(([t, d]) => (
          <div key={t}>
            <dt>{t}</dt>
            <dd>{d}</dd>
          </div>
        ))}
      </dl>
    </Page>
  );
}
