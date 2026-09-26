// Prompt registry loader: prompts/<name>/v<N>.md with a small frontmatter.
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, "../../prompts");

function parseFront(block) {
  const meta = {};
  for (const line of block.split("\n")) {
    const m = line.match(/^([a-z_]+):\s*(.*)$/);
    if (!m) continue;
    const [, key, raw] = m;
    if (raw.startsWith("[") || raw.startsWith("{")) meta[key] = JSON.parse(raw);
    else if (/^\d+$/.test(raw)) meta[key] = Number(raw);
    else meta[key] = raw;
  }
  return meta;
}

export function load(name, version) {
  const text = readFileSync(path.join(ROOT, name, `v${version}.md`), "utf8");
  const [, front, ...rest] = text.split("---\n");
  return { ...parseFront(front), body: rest.join("---\n").trim() };
}

export function render(prompt, values) {
  return prompt.body.replace(/\{\{(\w+)\}\}/g, (_, k) => String(values[k]));
}
