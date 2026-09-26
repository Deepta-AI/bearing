import { useEffect, useState, type ReactNode } from "react";

export type Frame = { title: string; where?: string; body: ReactNode; visual?: ReactNode };

/** A numbered walk through a real sequence, played or stepped. `visual(i)` draws the state after step i. */
export function Stepper({ frames, visual, interval = 3200, label }: { frames: Frame[]; visual?: (i: number) => ReactNode; interval?: number; label: string }) {
  const [i, setI] = useState(0);
  const [playing, setPlaying] = useState(false);
  useEffect(() => {
    if (!playing) return;
    if (i >= frames.length - 1) {
      setPlaying(false);
      return;
    }
    const id = window.setTimeout(() => setI((x) => x + 1), interval);
    return () => window.clearTimeout(id);
  }, [playing, i, frames.length, interval]);
  const f = frames[i];
  const end = i === frames.length - 1;
  return (
    <figure className="stepper wide panel" aria-label={label}>
      <ol className="st-rail">
        {frames.map((fr, n) => (
          <li key={n} className={n < i ? "past" : n === i ? "now" : ""}>
            <button type="button" onClick={() => { setPlaying(false); setI(n); }} aria-current={n === i ? "step" : undefined}>
              <span className="st-n">{n + 1}</span>
              <span className="st-t">{fr.title}</span>
            </button>
          </li>
        ))}
      </ol>
      <div className={visual ? "st-main two" : "st-main"}>
        <div className="st-text" key={i}>
          <h3>
            <span className="st-n">{i + 1}</span> {f.title}
          </h3>
          {f.where && <p className="st-where">{f.where}</p>}
          {f.body}
        </div>
        {visual && <div className="st-visual">{visual(i)}</div>}
      </div>
      <div className="an-ctl">
        <button type="button" onClick={() => { setPlaying(false); setI((x) => Math.max(0, x - 1)); }} disabled={i === 0}>
          Back
        </button>
        <button type="button" className="primary" onClick={() => { if (end) { setI(0); setPlaying(true); } else setPlaying((p) => !p); }}>
          {playing ? "Pause" : end ? "Play again" : "Play"}
        </button>
        <button type="button" onClick={() => { setPlaying(false); setI((x) => Math.min(frames.length - 1, x + 1)); }} disabled={end}>
          Next
        </button>
      </div>
    </figure>
  );
}
