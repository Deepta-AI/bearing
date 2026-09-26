import raw from "../data/internals.json";
import rec from "../data/recordings.json";

export type SkillFile = { path: string; lines: number };
export type Skill = {
  name: string;
  category: string;
  what: string;
  when: string;
  description: string;
  invocation: "command" | "auto";
  kind: "stack" | "step";
  args: string;
  tools: string[];
  extra: Record<string, string>;
  intro: string;
  sections: { title: string; lines: number }[];
  inputs: string[];
  steps: string[];
  output: string;
  gotchas: string[];
  layout: string;
  commands: string[];
  lines: number;
  files: SkillFile[];
  groups: Record<string, number>;
  evals: boolean;
};
export type Script = {
  path: string;
  name: string;
  lang: "bash" | "python";
  group: string;
  skill?: string;
  lines: number;
  header: string;
  functions: string[];
  env: string[];
  calls: string[];
};
export type Hook = { event: string; matcher: string; script: string; timeout: number; guard: string[]; body: string };
export type Agent = {
  name: string;
  description: string;
  tools: string[];
  disallowed: string[];
  model: string;
  maxTurns: string;
  isolation: string;
  intro: string;
  sections: string[];
  lines: number;
  usedBy: string[];
};
export type Stack = {
  id: string;
  display: string;
  type: string;
  stack: string;
  databases: string;
  entrypoint: string;
  rules_file: string;
  check_command?: string;
  install?: string;
  tool?: string;
  skill: string;
  dir: string;
  files: string[];
};
export type Test = { path: string; kind: string; lines: number; header: string; asserts: number };
export type Internals = {
  version: string;
  counts: Record<string, number>;
  skills: Skill[];
  scripts: Script[];
  hookDescription: string;
  hooks: Hook[];
  agents: Agent[];
  make: { name: string; does: string; inCheck: boolean }[];
  check: string[];
  ciHeader: string;
  ci: { name: string; stage: string; extends: string; image: string }[];
  tests: Test[];
  stacks: Stack[];
  templates: SkillFile[];
  changelog: { version: string; date: string; groups: string[]; entries: number; summary: string }[];
  evals: string[];
  evalsPending: string[];
  guardRules: { tool: string; pattern: string; label: string }[];
  settings: {
    allow: number;
    ask: number;
    deny: number;
    defaultMode: string;
    askSamples: string[];
    domains: number;
    allowWrite: string[];
    denyRead: string[];
    denyWrite: string[];
    rules: string[];
    unscopedRules: string[];
    sessionBytes: { agents: number; claude: number; unscopedRules: number };
    sessionTokens: number;
  };
  autopilot: { maxAttempts: number; stages: { name: string; skill: string; gate: string }[] };
};

export type RecLine = [number, string];
export type RecStep = { cmd: string; code: number; ms: number; out: RecLine[] };
export type Recording = { title: string; cwd: string; recorded: string; steps: RecStep[] };

export const data = raw as unknown as Internals;
export const recordings = rec as unknown as Record<string, Recording>;

export const skillByName = new Map(data.skills.map((s) => [s.name, s]));
export const scriptByName = new Map(data.scripts.filter((s) => s.group !== "skill").map((s) => [s.name, s]));
export const scriptByPath = new Map(data.scripts.map((s) => [s.path, s]));

export const CATEGORY_LABEL: Record<string, string> = {
  product: "Product",
  architecture: "Architecture",
  design: "Design",
  genai: "GenAI",
  repository: "Repository",
  stacks: "Stack lanes",
  "task flow": "Task flow",
  quality: "Quality",
  operate: "Operate",
  platform: "Platform",
  meta: "The kit itself",
};

export const GROUP_LABEL: Record<string, string> = {
  install: "Install and verify",
  guard: "The guard and harnesses",
  hooks: "Hook adapters",
  scaffold: "Scaffold and adopt",
  tracker: "Trackers",
  workflow: "Workflow helpers",
  generators: "Generators",
  quality: "Lints and evals",
  skill: "Scripts inside skills",
};

/** Where a repository path can be read on the git host, when the build knows the host. */
export const REPO_URL: string = (import.meta.env.VITE_REPO_URL as string | undefined) ?? "";
export function srcHref(path: string, line?: number) {
  if (!REPO_URL) return "";
  return `${REPO_URL.replace(/\/$/, "")}/-/blob/main/${path}${line ? `#L${line}` : ""}`;
}
