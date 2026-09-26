import { useEffect, useState } from "react";

/**
 * The guard's pipeline for one command, stage by stage. The stages and their
 * order are guard_command() in plugins/bearing/bin/brg-guard; each example's verdict and
 * message are what the guard printed in the recorded session (devguide
 * "guard" replay), so the ending of every walk is real output.
 */
type Tok = { t: string; k?: "wrap" | "verb" | "sep" | "var" | "rule" | "arg" | "dead" };
type Stage = { name: string; fn: string; say: string; segs: Tok[][] };
type Example = { id: string; label: string; cmd: string; verdict: "allowed" | "refused"; message: string; stages: Stage[] };

const pre = (cmd: string): Stage => ({
  name: "Read and pre-check",
  fn: "guard_command",
  say: "Not empty, no guard marker smuggled in, under 16,384 bytes (longer commands are refused outright, because the hook has a 10 second timeout), and no fork bomb. LC_ALL=C so every length is a byte count.",
  segs: [[{ t: cmd }]],
});

const EXAMPLES: Example[] = [
  {
    id: "env",
    label: "A push hidden behind env",
    cmd: "env GIT_TRACE=1 git push origin main",
    verdict: "refused",
    message: "Bearing blocked 'git push': the engineer pushes, merges and deploys; the agent prepares. Print the command for the engineer instead.",
    stages: [
      pre("env GIT_TRACE=1 git push origin main"),
      { name: "Heredocs and substitutions", fn: "strip_data_heredocs, extract_substitutions", say: "No << and no $( ) or backticks here, so nothing is lifted out. When there are, each $( ) is checked as a command of its own and replaced by a marker.", segs: [[{ t: "env" }, { t: "GIT_TRACE=1" }, { t: "git" }, { t: "push" }, { t: "origin" }, { t: "main" }]] },
      { name: "Split into segments", fn: "scan_segments", say: "Split on ; & | ( ) and newlines, respecting quotes and backslashes. One segment. Redirections become tokens of their own.", segs: [[{ t: "env" }, { t: "GIT_TRACE=1" }, { t: "git" }, { t: "push" }, { t: "origin" }, { t: "main" }]] },
      { name: "Strip wrappers", fn: "strip_wrappers", say: "env, sudo, command, exec, nohup, timeout, xargs, flock and friends run another program, so they are peeled off, along with their options and any NAME=value assignments. What is left is the program that really runs.", segs: [[{ t: "env", k: "dead" }, { t: "GIT_TRACE=1", k: "dead" }, { t: "git", k: "verb" }, { t: "push" }, { t: "origin" }, { t: "main" }]] },
      { name: "Match the rule table", fn: "match_tool_rules", say: "git is a table tool. Its 24 rules are tried against the arguments; the pattern push matches the first positional argument.", segs: [[{ t: "git", k: "verb" }, { t: "push", k: "rule" }, { t: "origin", k: "arg" }, { t: "main", k: "arg" }]] },
    ],
  },
  {
    id: "chain",
    label: "An amend after an innocent echo",
    cmd: "echo ok && git commit --amend --no-edit",
    verdict: "refused",
    message: "Bearing blocked 'git commit --amend': the engineer pushes, merges and deploys; the agent prepares. Print the command for the engineer instead.",
    stages: [
      pre("echo ok && git commit --amend --no-edit"),
      { name: "Split into segments", fn: "scan_segments", say: "&& ends a segment, so this is two commands. Every segment is checked; the first one being harmless proves nothing about the second.", segs: [[{ t: "echo" }, { t: "ok" }], [{ t: "git" }, { t: "commit" }, { t: "--amend" }, { t: "--no-edit" }]] },
      { name: "Segment 1: echo", fn: "check_tokens", say: "echo has no rule. Allowed, and the guard moves on.", segs: [[{ t: "echo", k: "verb" }, { t: "ok", k: "arg" }], [{ t: "git" }, { t: "commit" }, { t: "--amend" }, { t: "--no-edit" }]] },
      { name: "Segment 2: git", fn: "match_tool_rules", say: "The rule git|commit --amend needs the word commit and the flag --amend anywhere after it. Both are there.", segs: [[{ t: "echo", k: "dead" }, { t: "ok", k: "dead" }], [{ t: "git", k: "verb" }, { t: "commit", k: "rule" }, { t: "--amend", k: "rule" }, { t: "--no-edit", k: "arg" }]] },
    ],
  },
  {
    id: "var",
    label: "A verb the guard cannot read",
    cmd: "git $SUB origin",
    verdict: "refused",
    message: "brg-guard: the verb after git is a variable that cannot be read; refusing (fail closed)",
    stages: [
      pre("git $SUB origin"),
      { name: "Split into segments", fn: "scan_segments", say: "One segment, three tokens. The second is a variable.", segs: [[{ t: "git" }, { t: "$SUB" }, { t: "origin" }]] },
      { name: "Resolve variables", fn: "check_verb_token, resolve_vars_and_recurse", say: "A variable assigned earlier in the same command (SUB=status; git $SUB) would be substituted and the command checked again. This one is not assigned here, so its value is unknown: it could be push.", segs: [[{ t: "git", k: "verb" }, { t: "$SUB", k: "var" }, { t: "origin", k: "arg" }]] },
      { name: "Fail closed", fn: "refuse", say: "A command the guard cannot read is refused, never waved through. The same goes for a program name that comes from a substitution, and for hook JSON that jq could not parse.", segs: [[{ t: "git", k: "verb" }, { t: "$SUB", k: "var" }, { t: "origin", k: "dead" }]] },
    ],
  },
  {
    id: "ok",
    label: "Ordinary work goes through",
    cmd: "git status --short",
    verdict: "allowed",
    message: "(no output, exit 0: the command runs)",
    stages: [
      pre("git status --short"),
      { name: "Split into segments", fn: "scan_segments", say: "One segment.", segs: [[{ t: "git" }, { t: "status" }, { t: "--short" }]] },
      { name: "Match the rule table", fn: "match_tool_rules", say: "None of git's 24 rules names status. The decision is logged to .bearing/state/gates.log with its time in milliseconds, and the command runs. The recorded check took 23 ms.", segs: [[{ t: "git", k: "verb" }, { t: "status", k: "arg" }, { t: "--short", k: "arg" }]] },
    ],
  },
];

export function GuardAnatomy() {
  const [ex, setEx] = useState(0);
  const [st, setSt] = useState(0);
  const [playing, setPlaying] = useState(false);
  const e = EXAMPLES[ex];
  const last = e.stages.length; // index `last` is the verdict
  useEffect(() => {
    if (!playing) return;
    if (st >= last) {
      setPlaying(false);
      return;
    }
    const id = window.setTimeout(() => setSt((s) => s + 1), 2200);
    return () => window.clearTimeout(id);
  }, [playing, st, last]);

  const stage = e.stages[Math.min(st, last - 1)];
  const atVerdict = st >= last;
  return (
    <figure className="anatomy wide panel">
      <div className="an-top">
        <div className="filters" role="group" aria-label="Examples">
          {EXAMPLES.map((x, n) => (
            <button
              key={x.id}
              type="button"
              aria-pressed={n === ex}
              onClick={() => {
                setEx(n);
                setSt(0);
                setPlaying(true);
              }}
            >
              {x.label}
            </button>
          ))}
        </div>
      </div>
      <div className="an-cmd">
        <span className="ps1">$</span> {e.cmd}
      </div>
      <ol className="an-rail" aria-label="Stages">
        {e.stages.map((s, n) => (
          <li key={n} className={n < st ? "past" : n === st && !atVerdict ? "now" : ""}>
            <button type="button" onClick={() => { setPlaying(false); setSt(n); }}>
              {s.name}
            </button>
          </li>
        ))}
        <li className={atVerdict ? `now verdict ${e.verdict}` : `verdict ${e.verdict}`}>
          <button type="button" onClick={() => { setPlaying(false); setSt(last); }}>
            {e.verdict === "allowed" ? "Allowed" : "Refused"}
          </button>
        </li>
      </ol>
      <div className="an-stage" key={`${ex}-${st}`}>
        {atVerdict ? (
          <div className={`an-verdict ${e.verdict}`}>
            <div className="big">{e.verdict === "allowed" ? "exit 0" : "exit 2"}</div>
            <p>{e.message}</p>
          </div>
        ) : (
          <>
            <div className="an-segs">
              {stage.segs.map((seg, i) => (
                <div className="an-seg" key={i}>
                  {stage.segs.length > 1 && <span className="an-segn">segment {i + 1}</span>}
                  {seg.map((tk, j) => (
                    <span key={j} className={`tok ${tk.k ?? ""}`} style={{ animationDelay: `${j * 60}ms` }}>
                      {tk.t}
                    </span>
                  ))}
                </div>
              ))}
            </div>
            <p className="an-say">{stage.say}</p>
            <p className="an-fn">
              in <code>plugins/bearing/bin/brg-guard</code>: <code>{stage.fn}</code>
            </p>
          </>
        )}
      </div>
      <div className="an-ctl">
        <button type="button" onClick={() => { setPlaying(false); setSt((s) => Math.max(0, s - 1)); }} disabled={st === 0}>
          Back
        </button>
        <button type="button" className="primary" onClick={() => { if (atVerdict) { setSt(0); setPlaying(true); } else setPlaying((p) => !p); }}>
          {playing ? "Pause" : atVerdict ? "Play again" : "Play"}
        </button>
        <button type="button" onClick={() => { setPlaying(false); setSt((s) => Math.min(last, s + 1)); }} disabled={atVerdict}>
          Next
        </button>
      </div>
      <figcaption className="an-cap">
        Legend: <span className="tok verb">program</span> <span className="tok rule">matched by a rule</span> <span className="tok var">unreadable</span>{" "}
        <span className="tok dead">set aside</span>
      </figcaption>
    </figure>
  );
}
