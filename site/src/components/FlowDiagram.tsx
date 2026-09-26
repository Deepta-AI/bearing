import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { Link } from "react-router";
import { data, packKey, skillByName, type Flow, type FlowNode, type FlowStep } from "../lib/data";
import { PackTag } from "./ui";

type Selection = Record<number, number[]>; // branch index -> chosen option indexes

/** Every branch in a flow gets a fixed number, depth first, once. */
function numberBranches(nodes: FlowNode[], m = new Map<FlowNode, number>()) {
  for (const n of nodes)
    if (n.kind === "branch") {
      m.set(n, m.size);
      n.options.forEach((o) => numberBranches(o.steps, m));
    }
  return m;
}

/** The steps a reader walks through, in order, given the branch choices. */
function visibleSteps(nodes: FlowNode[], sel: Selection, ids: Map<FlowNode, number>): FlowStep[] {
  const out: FlowStep[] = [];
  for (const n of nodes) {
    if (n.kind === "step") out.push(n);
    else if (n.kind === "branch") {
      const chosen = sel[ids.get(n) ?? -1] ?? [];
      n.options.forEach((o, oi) => {
        if (chosen.includes(oi)) out.push(...visibleSteps(o.steps, sel, ids));
      });
    }
  }
  return out;
}

const chev = (
  <svg className="chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
    <path d="m6 9 6 6 6-6" />
  </svg>
);

function StepCard({
  step,
  open,
  active,
  onToggle,
  refFn,
  index,
}: {
  step: FlowStep;
  open: boolean;
  active: boolean;
  onToggle: () => void;
  refFn: (el: HTMLDivElement | null) => void;
  index: number;
}) {
  const reduce = useReducedMotion();
  const c = `var(--${packKey(step.pack) === "bearing" ? "jade" : packKey(step.pack)})`;
  return (
    <motion.div
      ref={refFn}
      id={`step-${step.id}`}
      className={`node${active ? " active" : ""}${step.optional ? " optional" : ""}`}
      style={{ ["--c" as string]: c }}
      initial={reduce ? false : { opacity: 0, x: -10 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ delay: reduce ? 0 : Math.min(index * 0.045, 0.9), duration: 0.28, ease: "easeOut" }}
    >
      <span className="pin" aria-hidden="true" />
      <div className="card-step" data-open={open}>
        <button type="button" aria-expanded={open} onClick={onToggle}>
          <span className="t">
            {step.title}
            {step.optional && <small>optional</small>}
          </span>
          <span className="sk">
            <code>{step.skill}</code>
            <PackTag pack={step.pack} />
            {chev}
          </span>
        </button>
        <AnimatePresence initial={false}>
          {open && (
            <motion.div
              key="body"
              initial={reduce ? false : { height: 0, opacity: 0 }}
              animate={{ height: "auto", opacity: 1 }}
              exit={reduce ? undefined : { height: 0, opacity: 0 }}
              transition={{ duration: 0.22, ease: "easeOut" }}
              style={{ overflow: "hidden" }}
            >
              <div className="body">
                <div>
                  <h4>What it does</h4>
                  <p>{step.does}</p>
                </div>
                <div>
                  <h4>Why this step</h4>
                  <p>{step.why}</p>
                </div>
                <div>
                  <h4>You get</h4>
                  <p>{step.output}</p>
                </div>
                <div className="acts">
                  <span className="muted">Type</span> <code>{step.skill}</code>
                  {skillByName.has(step.skill.split(" ")[0]) && <Link to={`/skills/${step.skill.split(" ")[0]}`}>About this skill</Link>}
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </motion.div>
  );
}

export default function FlowDiagram({ flow, initialStep }: { flow: Flow; initialStep?: string }) {
  const [sel, setSel] = useState<Selection>({});
  const [open, setOpen] = useState<Set<string>>(() => new Set(initialStep ? [initialStep] : []));
  const [active, setActive] = useState<number>(-1);
  const [playing, setPlaying] = useState(false);
  const refs = useRef(new Map<string, HTMLDivElement>());
  const box = useRef<HTMLDivElement>(null);
  const [fill, setFill] = useState(0);
  const reduce = useReducedMotion();

  const ids = useMemo(() => numberBranches(flow.steps), [flow]);
  const steps = useMemo(() => visibleSteps(flow.steps, sel, ids), [flow, sel, ids]);

  useEffect(() => {
    setSel({});
    setActive(-1);
    setPlaying(false);
    setOpen(new Set(initialStep ? [initialStep] : []));
  }, [flow.id, initialStep]);

  useEffect(() => {
    if (!initialStep) return;
    const i = steps.findIndex((s) => s.id === initialStep);
    if (i >= 0) {
      setActive(i);
      requestAnimationFrame(() => refs.current.get(initialStep)?.scrollIntoView({ block: "center" }));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialStep, flow.id]);

  // The filled part of the spine reaches the active step.
  useLayoutEffect(() => {
    const st = steps[active];
    const el = st && refs.current.get(st.id);
    if (!el || !box.current) return setFill(0);
    const top = el.getBoundingClientRect().top - box.current.getBoundingClientRect().top;
    setFill(top + 27);
  }, [active, steps, open, sel]);

  const goTo = useCallback(
    (i: number) => {
      const st = steps[i];
      if (!st) return;
      setActive(i);
      setOpen(new Set([st.id]));
      requestAnimationFrame(() => refs.current.get(st.id)?.scrollIntoView({ block: "center", behavior: reduce ? "auto" : "smooth" }));
    },
    [steps, reduce],
  );

  useEffect(() => {
    if (!playing) return;
    if (active >= steps.length - 1) {
      setPlaying(false);
      return;
    }
    const t = setTimeout(() => goTo(active + 1), active < 0 ? 200 : 2600);
    return () => clearTimeout(t);
  }, [playing, active, steps.length, goTo]);

  const toggle = (id: string) => {
    setOpen((o) => {
      const n = new Set(o);
      if (n.has(id)) n.delete(id);
      else n.add(id);
      return n;
    });
    const i = steps.findIndex((s) => s.id === id);
    if (i >= 0) setActive(i);
  };

  let stepNo = 0;
  const render = (nodes: FlowNode[]): React.ReactNode =>
    nodes.map((n, k) => {
      if (n.kind === "phase") return <div className="phase" key={`p${k}`}>{n.title}</div>;
      if (n.kind === "link") {
        const target = data.flows.find((f) => f.id === n.flow);
        return (
          <div className="node" key={`l${k}`} style={{ ["--c" as string]: "var(--jade)" }}>
            <span className="pin" aria-hidden="true" />
            <Link className="linknode" to={`/flows/${n.flow}`}>
              {n.title}: open the {target?.title.toLowerCase()} flow
            </Link>
          </div>
        );
      }
      if (n.kind === "step") {
        const i = steps.findIndex((s) => s.id === n.id);
        return (
          <StepCard
            key={n.id}
            step={n}
            index={stepNo++}
            open={open.has(n.id)}
            active={i === active && i >= 0}
            onToggle={() => toggle(n.id)}
            refFn={(el) => {
              if (el) refs.current.set(n.id, el);
              else refs.current.delete(n.id);
            }}
          />
        );
      }
      const bi = ids.get(n) ?? -1;
      const chosen = sel[bi] ?? [];
      return (
        <div className="branch" key={`b${bi}`}>
          <div className="q">{n.question}</div>
          <div className="opts" role="group" aria-label={n.question}>
            {n.options.map((o, oi) => (
              <button
                key={o.label}
                type="button"
                aria-pressed={chosen.includes(oi)}
                onClick={() =>
                  setSel((s) => {
                    const cur = s[bi] ?? [];
                    const next = n.multi ? (cur.includes(oi) ? cur.filter((x) => x !== oi) : [...cur, oi]) : cur.includes(oi) ? [] : [oi];
                    return { ...s, [bi]: next };
                  })
                }
              >
                {o.label}
                {o.steps.length > 0 && <span className="muted"> ({o.steps.length})</span>}
              </button>
            ))}
            <span className="muted" style={{ fontSize: ".84rem", alignSelf: "center" }}>
              {n.multi ? "choose any that apply" : "choose one"}
            </span>
          </div>
          <AnimatePresence initial={false}>
            {n.options.map((o, oi) =>
              chosen.includes(oi) && o.steps.length > 0 ? (
                <motion.div
                  className="lane"
                  key={o.label}
                  initial={reduce ? false : { opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  exit={reduce ? undefined : { opacity: 0, height: 0 }}
                  transition={{ duration: 0.25 }}
                  style={{ overflow: "hidden" }}
                >
                  <div className="lbl">{o.label}</div>
                  {render(o.steps)}
                </motion.div>
              ) : null,
            )}
          </AnimatePresence>
        </div>
      );
    });

  return (
    <div>
      <div className="player" aria-label="Walk through the flow">
        <button type="button" className="btn primary" onClick={() => (playing ? setPlaying(false) : (active >= steps.length - 1 && setActive(-1), setPlaying(true)))}>
          {playing ? (
            <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><rect x="6" y="5" width="4" height="14" rx="1" /><rect x="14" y="5" width="4" height="14" rx="1" /></svg>
          ) : (
            <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M7 5v14l12-7z" /></svg>
          )}
          {playing ? "Pause" : active >= 0 ? "Resume" : "Walk me through it"}
        </button>
        <button type="button" className="btn" disabled={active <= 0} onClick={() => { setPlaying(false); goTo(active - 1); }}>
          Previous
        </button>
        <span className="pos">{active >= 0 ? `${active + 1} / ${steps.length}` : `${steps.length} steps`}</span>
        <button type="button" className="btn" disabled={active >= steps.length - 1} onClick={() => { setPlaying(false); goTo(active + 1); }}>
          Next
        </button>
        <button type="button" className="btn" onClick={() => setOpen(open.size ? new Set() : new Set(steps.map((s) => s.id)))}>
          {open.size ? "Collapse all" : "Expand all"}
        </button>
      </div>
      <div className="legend">
        {[["bearing", "--jade"], ["Superpowers", "--sp"], ["gstack", "--gs"], ["GSD Core", "--gsd"], ["Other packs", "--bi"]].map(([l, v]) => (
          <span key={l} style={{ ["--c" as string]: `var(${v})` }}>
            <i />
            {l}
          </span>
        ))}
        <span>Dashed ring: optional step. Diamond: a decision; choose an answer to see its steps.</span>
      </div>
      <div className="diagram" ref={box}>
        <span className="spine" aria-hidden="true" />
        <motion.span
          className="spine-fill"
          aria-hidden="true"
          initial={false}
          animate={{ height: Math.max(fill, 0) }}
          transition={{ duration: reduce ? 0 : 0.5, ease: "easeInOut" }}
        />
        {render(flow.steps)}
      </div>
    </div>
  );
}
