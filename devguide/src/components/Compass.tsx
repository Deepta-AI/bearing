import { useEffect, useRef, useState } from "react";
import { Link } from "react-router";
import { data } from "../lib/data";

/** What each Claude Code hook event does in a Bearing repository, in the order a session meets them. */
export const EVENTS: { event: string; short: string; when: string; does: string; blocks: string; tone: "sea" | "signal" | "brass" | "jade" }[] = [
  {
    event: "SessionStart",
    short: "Start",
    when: "A session starts, resumes, or comes back from compaction.",
    does: "Prints the branch, the task id, how many files are changed and the first 20 lines of the handoff note, so the model starts where the last session stopped. It also records when this session began, which the Stop gate uses later.",
    blocks: "Never blocks. What it prints goes into the model's context.",
    tone: "sea",
  },
  {
    event: "UserPromptSubmit",
    short: "Prompt",
    when: "You press enter on a prompt.",
    does: "When the branch carries a ticket id (TASK-142) that the prompt does not mention, adds one line: Task: TASK-142, use it in commit messages.",
    blocks: "Never blocks. It adds a hint.",
    tone: "sea",
  },
  {
    event: "PreToolUse",
    short: "Before Bash",
    when: "The model is about to run a shell command.",
    does: "Hands the command to the guard, which takes it apart (wrappers, substitutions, heredocs, chained segments) and checks every program against 135 rules. Push, amend, rebase, deploy, publish and deletes outside the repository are refused.",
    blocks: "Exit 2 refuses the command, and the reason goes back to the model.",
    tone: "signal",
  },
  {
    event: "PostToolUse",
    short: "After edit",
    when: "The model has just edited or written a file.",
    does: "Formats the file with the repository's formatter, then lints that one file (make check-file when the Makefile has it). Problems go straight back, so they are fixed now instead of at make check.",
    blocks: "Sends the model back with the linter output ({\"decision\": \"block\"}). The edit itself has already happened.",
    tone: "brass",
  },
  {
    event: "PreCompact",
    short: "Compact",
    when: "The context window is about to be summarised.",
    does: "Writes the branch, the changes, whether make check has passed, and the last three things you asked for into .bearing/state/<branch>.compact.md. The next SessionStart reads it back.",
    blocks: "Never blocks.",
    tone: "sea",
  },
  {
    event: "Stop",
    short: "Stop",
    when: "The model thinks it has finished.",
    does: "If files this session changed have not passed make check since, sends the model back once to run it. On the second stop it only reminds, so it can never loop.",
    blocks: "Blocks once, then reminds.",
    tone: "jade",
  },
];

const R = 150;

export function Compass() {
  const [i, setI] = useState(0);
  const [tour, setTour] = useState(true);
  const root = useRef<HTMLDivElement>(null);
  const hooks = data.hooks;
  const h = hooks.find((x) => x.event === EVENTS[i].event);
  const e = EVENTS[i];

  // One tour through the six events when the dial first comes into view; any
  // interaction ends it. Reduced motion: no tour.
  useEffect(() => {
    if (window.matchMedia?.("(prefers-reduced-motion: reduce)").matches) {
      setTour(false);
      return;
    }
    if (!tour) return;
    const id = window.setTimeout(() => {
      setI((x) => {
        if (x >= EVENTS.length - 1) {
          setTour(false);
          return x;
        }
        return x + 1;
      });
    }, 3800);
    return () => window.clearTimeout(id);
  }, [i, tour]);

  const pick = (n: number) => {
    setTour(false);
    setI((n + EVENTS.length) % EVENTS.length);
  };
  const angle = (n: number) => (n * 360) / EVENTS.length;

  return (
    <div className="compass wide" ref={root}>
      <div className="dial">
        <svg viewBox="-200 -200 400 400" role="group" aria-label="The six hook events of a session">
          <circle r={R + 30} className="ring-outer" />
          <circle r={R} className="ring" />
          <circle r={R - 46} className="ring-inner" />
          {Array.from({ length: 72 }, (_, k) => {
            const a = (k * 5 * Math.PI) / 180;
            const long = k % 6 === 0;
            const r1 = R + 30;
            const r2 = R + 30 - (long ? 12 : 6);
            return <line key={k} x1={Math.sin(a) * r1} y1={-Math.cos(a) * r1} x2={Math.sin(a) * r2} y2={-Math.cos(a) * r2} className={long ? "tick long" : "tick"} />;
          })}
          {EVENTS.map((ev, n) => {
            const a = (angle(n) * Math.PI) / 180;
            const x = Math.sin(a) * R;
            const y = -Math.cos(a) * R;
            const lx = Math.sin(a) * (R - 26);
            const ly = -Math.cos(a) * (R - 26);
            return (
              <g
                key={ev.event}
                className={`station ${ev.tone} ${n === i ? "on" : ""}`}
                role="button"
                tabIndex={0}
                aria-pressed={n === i}
                aria-label={`${ev.event}: ${ev.when}`}
                onClick={() => pick(n)}
                onKeyDown={(k) => {
                  if (k.key === "Enter" || k.key === " ") {
                    k.preventDefault();
                    pick(n);
                  }
                  if (k.key === "ArrowRight") pick(i + 1);
                  if (k.key === "ArrowLeft") pick(i - 1);
                }}
              >
                <circle cx={x} cy={y} r={n === i ? 12 : 8} />
                <text x={lx} y={ly} textAnchor="middle" dominantBaseline="middle">
                  {ev.short}
                </text>
              </g>
            );
          })}
          <g className="needle" style={{ transform: `rotate(${angle(i)}deg)` }}>
            <path d={`M0 ${-(R - 40)} L9 0 L0 ${R - 90} L-9 0 Z`} />
            <path d={`M0 ${-(R - 40)} L9 0 L-9 0 Z`} className="north" />
          </g>
          <circle r="7" className="hub" />
        </svg>
        <div className="dial-foot">
          <button type="button" onClick={() => pick(i - 1)} aria-label="Previous event">
            ‹
          </button>
          <span>
            {i + 1} of {EVENTS.length}
          </span>
          <button type="button" onClick={() => pick(i + 1)} aria-label="Next event">
            ›
          </button>
        </div>
      </div>
      <div className={`dial-panel ${e.tone}`} aria-live="polite">
        <div className="ev">
          <span className="dot" />
          <code>{e.event}</code>
          {h?.matcher && <span className="matcher">matcher {h.matcher}</span>}
        </div>
        <p className="when">{e.when}</p>
        <p>{e.does}</p>
        <p className="blocks">{e.blocks}</p>
        {h && (
          <>
            <div className="chain">
              <span className="chip">hooks/hooks.json</span>
              <span aria-hidden="true">→</span>
              <Link className="chip sea" to={`/scripts/${h.script}`}>
                {h.script}
              </Link>
              <span aria-hidden="true">→</span>
              <Link className="chip brass" to="/guard">
                brg-guard {h.guard.join(", ")}
              </Link>
              <span className="chip">timeout {h.timeout} s</span>
            </div>
            <pre className="dial-code">{h.body.split("\n").filter((l) => !l.startsWith("#!")).join("\n")}</pre>
          </>
        )}
      </div>
    </div>
  );
}
