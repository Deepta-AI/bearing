import raw from "../data/handbook.json";

export type Skill = {
  name: string;
  category: string;
  invocation: "command" | "auto";
  what: string;
  when: string;
  phrases: string[];
  args: string;
};
export type Row = { stage: string; skill: string; from: string; output: string; alternate: string };
export type Stage = { title: string; when: string; rows: Row[] };
export type Alt = { skill: string; pack: string; when: string };
export type FlowStep = {
  kind: "step";
  id: string;
  title: string;
  skill: string;
  pack: string;
  does: string;
  output: string;
  why: string;
  alternates: Alt[];
  optional?: boolean;
};
export type FlowBranch = {
  kind: "branch";
  question: string;
  multi?: boolean;
  options: { label: string; steps: FlowNode[] }[];
};
export type FlowNode =
  | FlowStep
  | FlowBranch
  | { kind: "phase"; title: string }
  | { kind: "link"; title: string; flow: string };
export type Flow = { id: string; title: string; tagline: string; when: string; steps: FlowNode[] };
export type Verdict = "bearing-stronger" | "alternative-stronger" | "different-job" | "no-alternative" | "unverified";
export type Comparison = {
  best_alternative: { name: string; pack: string; installed: boolean; invoke?: string } | null;
  verdict: Verdict;
  why: string;
  use_alternative_when: string;
  use_bearing_when: string;
  recommendation: "keep" | "supersede" | "feed-rules";
  confidence: "high" | "medium" | "low";
  measured?: Measured;
};

export type MeasuredArm = { pass_rate: number; tokens: number; seconds: number };
export type Measured = {
  date: string;
  model: string;
  iteration: number;
  cases: number;
  runs_per_arm: number;
  arms: Partial<Record<"with_skill" | "with_the_alternative" | "without_skill", MeasuredArm>>;
  result: "bearing ahead" | "rival ahead" | "within 10 points";
  closest: string;
  margin: number;
};

export type DefaultFile = {
  path: string;
  source?: string;
  lang: string;
  group?: string;
  installedBy: string;
  purpose: string;
  edit: string;
  keep: string;
  note?: string;
  content?: string;
};
export type Scope = { id: string; title: string; summary: string; files: DefaultFile[] };

type Data = {
  version: string;
  skills: Skill[];
  categories: string[];
  stages: Stage[];
  alternates: Record<string, string>;
  notes: string[];
  flows: Flow[];
  comparisons: Record<string, Comparison>;
  defaultFiles: Scope[];
  config: { key: string; meaning: string; default: string }[];
  roles: { role: string; blurb: string; rows: { stage: string; row: string }[] }[];
  stacks: string[];
  guardVerbs: number;
  walkthrough: string;
};

export const data = raw as unknown as Data;
export const skillByName = new Map(data.skills.map((s) => [s.name, s]));

/** The pack a skill belongs to, as a colour key: Bearing, sp, gs, gsd, bi. */
export function packKey(pack: string): "bearing" | "sp" | "gs" | "gsd" | "bi" {
  const p = pack.toLowerCase();
  if (p === "bearing" || p.startsWith("bearing")) return "bearing";
  if (p.includes("superpowers")) return "sp";
  if (p.includes("gstack")) return "gs";
  if (p.includes("gsd")) return "gsd";
  return "bi";
}

/** How a user types a skill: gstack skills are slash commands. */
export function invokeName(name: string, pack: string): string {
  return packKey(pack) === "gs" && !name.startsWith("/") ? `/${name}` : name;
}

export function packName(pack: string): string {
  const k = packKey(pack);
  return k === "bearing" ? "bearing" : pack;
}

/** Stage rows that name this skill as the main choice. */
export function rowsFor(name: string) {
  const out: { stage: string; row: Row }[] = [];
  for (const st of data.stages) for (const r of st.rows) if (r.skill === name) out.push({ stage: st.title, row: r });
  return out;
}

/** Flow steps that use this skill as the main or an alternate. */
export function flowUses(name: string) {
  const out: { flow: Flow; step: FlowStep; asAlternate: boolean }[] = [];
  const bare = (s: string) => s.split(" ")[0].replace(/^\//, "");
  const visit = (flow: Flow, nodes: FlowNode[]) => {
    for (const n of nodes) {
      if (n.kind === "step") {
        if (bare(n.skill) === bare(name)) out.push({ flow, step: n, asAlternate: false });
        else if (n.alternates.some((a) => bare(a.skill) === bare(name))) out.push({ flow, step: n, asAlternate: true });
      } else if (n.kind === "branch") n.options.forEach((o) => visit(flow, o.steps));
    }
  };
  data.flows.forEach((f) => visit(f, f.steps));
  return out;
}

export const verdictLabel: Record<Verdict, string> = {
  "bearing-stronger": "bearing is the stronger choice",
  "alternative-stronger": "Use the alternative",
  "different-job": "Different job",
  "no-alternative": "No alternative installed",
  unverified: "Alternative not installed",
};
