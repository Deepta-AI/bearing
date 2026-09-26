import { readFileSync } from "node:fs";
import { join } from "node:path";

// @ts-check
/**
 * A Vite plugin that gives search every section heading, read from the page
 * sources at build time, so nothing is typed twice. It reads the routes in
 * src/main.tsx, finds each routed page component, and takes the page title,
 * its `toc` entries and its `<h2 id>` / `<H2 id>` headings.
 * Import it in the app as `import sections from "virtual:sections"`.
 */
/** @param {string} appRoot */
export function sectionsPlugin(appRoot) {
  const ID = "virtual:sections";
  const RID = "\0" + ID;
  const scan = () => {
    const src = join(appRoot, "src");
    const main = readFileSync(join(src, "main.tsx"), "utf8");
    /** @type {Map<string, { file: string; def: boolean }>} */
    const fileOf = new Map();
    for (const m of main.matchAll(/import\s+(\w+)\s+from\s+"\.\/pages\/(\w+)"/g)) fileOf.set(m[1], { file: m[2], def: true });
    for (const m of main.matchAll(/import\s*\{([^}]+)\}\s*from\s+"\.\/pages\/(\w+)"/g))
      for (const n of m[1].split(",").map((x) => x.trim()).filter(Boolean)) fileOf.set(n, { file: m[2], def: false });
    /** @type {{ route: string; page: string; id: string; label: string }[]} */
    const out = [];
    for (const r of main.matchAll(/\{\s*(?:index:\s*true|path:\s*"([^"]+)")\s*,\s*element:\s*<(\w+)\s*\/>/g)) {
      const path = r[1] === undefined ? "" : r[1];
      if (path.includes(":") || path === "*") continue;
      const f = fileOf.get(r[2]);
      if (!f) continue;
      const code = readFileSync(join(src, "pages", `${f.file}.tsx`), "utf8");
      const start = f.def ? code.search(/export default function \w+\s*\(/) : code.search(new RegExp(`export function ${r[2]}\\s*\\(`));
      if (start < 0) continue;
      const rest = code.slice(start + 10);
      const end = rest.search(/\nexport /);
      const body = end < 0 ? rest : rest.slice(0, end);
      const page = body.match(/\btitle="([^"]+)"/)?.[1] ?? r[2];
      const seen = new Set();
      /** @param {string} id @param {string} label */
      const add = (id, label) => {
        label = label.replace(/\s+/g, " ").trim();
        if (!seen.has(id) && label) {
          seen.add(id);
          out.push({ route: `/${path}`, page, id, label });
        }
      };
      for (const t of body.matchAll(/\{\s*id:\s*"([^"]+)",\s*label:\s*"([^"]+)"\s*\}/g)) add(t[1], t[2]);
      for (const h of body.matchAll(/<(?:h2|H2)\b[^>]*\bid="([^"]+)"[^>]*>([^<{]+)</g)) add(h[1], h[2]);
    }
    return out;
  };
  return {
    name: "bearing-sections",
    /** @param {string} id */
    resolveId(id) {
      return id === ID ? RID : undefined;
    },
    /** @param {string} id */
    load(id) {
      if (id !== RID) return undefined;
      const s = scan();
      if (!s.length) throw new Error("bearing-sections: 0 sections found in src/pages; search would have no sections");
      return `export default ${JSON.stringify(s)};`;
    },
  };
}
