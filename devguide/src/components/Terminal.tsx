import { useEffect, useMemo, useRef, useState } from "react";
import { recordings, type RecStep } from "../lib/data";

/**
 * A recorded terminal session, replayed. Every character is what the command
 * printed when devguide/scripts/record.py ran it; only the waits are shortened
 * (a pause over 0.7 s plays as 0.7 s, then divided by the speed).
 */
type Ev = { at: number; step: number; kind: "type"; upto: number } | { at: number; step: number; kind: "line"; n: number } | { at: number; step: number; kind: "done" };

function schedule(steps: RecStep[]) {
  const evs: Ev[] = [];
  let t = 0.3;
  steps.forEach((st, i) => {
    const per = Math.min(0.022, 0.9 / Math.max(st.cmd.length, 1));
    for (let c = 1; c <= st.cmd.length; c++) {
      if (c % 2 === 0 || c === st.cmd.length) evs.push({ at: t + c * per, step: i, kind: "type", upto: c });
    }
    t += st.cmd.length * per + 0.35;
    let last = 0;
    st.out.forEach(([at], n) => {
      t += Math.min(Math.max(at - last, 0), 0.7) + 0.035;
      last = at;
      evs.push({ at: t, step: i, kind: "line", n: n + 1 });
    });
    t += 0.25;
    evs.push({ at: t, step: i, kind: "done" });
    t += 0.55;
  });
  return { evs, total: t };
}

export function Terminal({ id, steps: only, title, height = 360 }: { id: string; steps?: number[]; title?: string; height?: number }) {
  const rec = recordings[id];
  const steps = useMemo(() => (rec ? rec.steps.filter((_, i) => !only || only.includes(i)) : []), [rec, only]);
  const { evs, total } = useMemo(() => schedule(steps), [steps]);
  const reduce = typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  const [t, setT] = useState(reduce ? total + 1 : 0);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(1);
  const raf = useRef(0);
  const body = useRef<HTMLDivElement>(null);
  const started = t > 0;

  useEffect(() => {
    if (!playing) return;
    let prev = performance.now();
    const tick = (now: number) => {
      const dt = ((now - prev) / 1000) * speed;
      prev = now;
      setT((x) => {
        const nx = x + dt;
        if (nx >= total) {
          setPlaying(false);
          return total + 0.01;
        }
        return nx;
      });
      raf.current = requestAnimationFrame(tick);
    };
    raf.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf.current);
  }, [playing, speed, total]);

  // What is on screen at time t.
  const view = useMemo(() => {
    const st = steps.map(() => ({ typed: 0, lines: 0, done: false, shown: false }));
    for (const e of evs) {
      if (e.at > t) break;
      const s = st[e.step];
      s.shown = true;
      if (e.kind === "type") s.typed = e.upto;
      else if (e.kind === "line") s.lines = e.n;
      else s.done = true;
    }
    return st;
  }, [evs, t, steps]);

  useEffect(() => {
    const el = body.current;
    if (el && playing) el.scrollTop = el.scrollHeight;
  }, [view, playing]);

  if (!rec) return <p>Recording {id} is missing; run devguide/scripts/record.py.</p>;
  const finished = t >= total;
  const realMs = steps.reduce((a, s) => a + s.ms, 0);

  return (
    <figure className="term wide" aria-label={`Terminal replay: ${title ?? rec.title}`}>
      <div className="term-bar">
        <span className="dots" aria-hidden="true">
          <i />
          <i />
          <i />
        </span>
        <span className="term-title">{title ?? rec.title}</span>
        <span className="term-ctl">
          <button type="button" onClick={() => setSpeed((s) => (s === 1 ? 2 : s === 2 ? 4 : 1))} aria-label="Replay speed">
            {speed}×
          </button>
          <button type="button" onClick={() => setT(total + 1)} disabled={finished}>
            Show all
          </button>
          <button
            type="button"
            className="primary"
            onClick={() => {
              if (finished) {
                setT(0);
                setPlaying(true);
              } else setPlaying((p) => !p);
            }}
          >
            {playing ? "Pause" : finished && started ? "Replay" : started ? "Resume" : "Play"}
          </button>
        </span>
      </div>
      <div className="term-body" ref={body} style={{ height }} aria-live="off">
        {!started && (
          <button type="button" className="term-start" onClick={() => setPlaying(true)}>
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M8 5v14l11-7z" fill="currentColor" />
            </svg>
            <span>
              Play the recording
              <small>
                {steps.length} command{steps.length > 1 ? "s" : ""}, real output, recorded {rec.recorded}
              </small>
            </span>
          </button>
        )}
        {steps.map((s, i) => {
          const v = view[i];
          if (!v.shown) return null;
          return (
            <div className="term-step" key={i}>
              <div className="term-cmd">
                <span className="ps1">$</span> {s.cmd.slice(0, v.typed)}
                {!v.done && v.lines === 0 && <span className="caret" />}
              </div>
              {s.out.slice(0, v.lines).map(([, line], n) => (
                <div className={`term-line ${lineTone(line)}`} key={n}>
                  {line || " "}
                </div>
              ))}
              {v.done && (
                <div className="term-exit">
                  <span className={s.code === 0 ? "ok" : "bad"}>exit {s.code}</span>
                  <span>{fmtMs(s.ms)}</span>
                </div>
              )}
            </div>
          );
        })}
      </div>
      <figcaption>
        Recorded with <code>devguide/scripts/record.py</code> in <code>{rec.cwd}</code>. The commands took {fmtMs(realMs)} of real time; the replay
        shortens waits, never the text.
      </figcaption>
    </figure>
  );
}

function fmtMs(ms: number) {
  return ms < 1000 ? `${ms} ms` : ms < 60000 ? `${(ms / 1000).toFixed(1)} s` : `${Math.floor(ms / 60000)} min ${Math.round((ms % 60000) / 1000)} s`;
}

function lineTone(line: string) {
  if (/\bFAIL\b|blocked|refus|not met|MISSING|FAILED/.test(line)) return "bad";
  if (/: .*\b0 (problems|failed|em dashes|stale)|passed|up to date|clean\b|^added|^ok\b|files written/.test(line)) return "good";
  if (/^(note|host|lockfile|kept|appended)/.test(line)) return "dim";
  return "";
}
