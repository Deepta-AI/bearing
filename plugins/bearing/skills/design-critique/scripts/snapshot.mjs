#!/usr/bin/env node
// snapshot: the bridge from a framework design gallery to pairs.py. pairs.py
// reads static HTML and the stylesheets it links; a Next.js or Vite gallery
// built with Tailwind v4 keeps its colours in @layer blocks and runtime
// classes that pairs.py cannot resolve. This renders each page in Chrome,
// light and dark, and writes a static snapshot per page: the page's HTML with
// a key on every element, and one stylesheet holding each element's computed
// colours, sizes, borders and focus ring (light as plain rules, dark under
// [data-theme="dark"] and again under prefers-color-scheme: dark). Then run
// pairs.py over the written .html files.
//
//   node snapshot.mjs --base <gallery url> --out <dir> <page>...
//
// Playwright is resolved from the repository being reviewed (its
// node_modules), so this needs @playwright/test or playwright-core installed
// there; CHROME_PATH picks a browser, else Playwright's own Chromium.
// Hover states are not measured; the report says so.
import fs from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { pathToFileURL } from "node:url";

const args = process.argv.slice(2);
let base = "";
let outDir = "";
const pages = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--base") base = args[++i] ?? "";
  else if (args[i] === "--out") outDir = args[++i] ?? "";
  else pages.push(args[i]);
}
if (!base || !outDir) {
  console.error("snapshot: usage: snapshot.mjs --base <gallery url> --out <dir> <page>...");
  process.exit(2);
}
if (pages.length === 0) {
  console.error("snapshot: 0 pages given, nothing written");
  process.exit(1);
}

let chromium;
try {
  const req = createRequire(path.join(process.cwd(), "package.json"));
  let entry;
  try {
    entry = req.resolve("playwright-core");
  } catch {
    entry = createRequire(req.resolve("@playwright/test")).resolve("playwright-core");
  }
  const mod = await import(pathToFileURL(entry).href);
  chromium = mod.chromium ?? mod.default?.chromium;
  if (!chromium) throw new Error("no chromium export");
} catch {
  console.error(
    "snapshot: playwright-core is not installed in this repository (run from the app's root after its dependencies are installed); nothing written",
  );
  process.exit(1);
}
fs.mkdirSync(outDir, { recursive: true });

const COLLECT = () => {
  const cv = document.createElement("canvas");
  cv.width = cv.height = 1;
  const cx = cv.getContext("2d", { willReadFrequently: true });
  const rgba = (c) => {
    if (!c || c === "transparent") return "rgba(0, 0, 0, 0)";
    cx.clearRect(0, 0, 1, 1);
    cx.fillStyle = "#000";
    cx.fillStyle = c;
    cx.fillRect(0, 0, 1, 1);
    const [r, g, b, a] = cx.getImageData(0, 0, 1, 1).data;
    return a === 255 ? `rgb(${r}, ${g}, ${b})` : `rgba(${r}, ${g}, ${b}, ${(a / 255).toFixed(3)})`;
  };
  const els = [document.body, ...document.body.querySelectorAll("*")];
  const out = [];
  const focusables = [];
  let k = 0;
  for (const e of els) {
    if (["SCRIPT", "STYLE", "LINK", "NOSCRIPT", "TEMPLATE"].includes(e.tagName)) continue;
    if (e.closest("nextjs-portal")) continue;
    e.setAttribute("data-k", String(k));
    const s = getComputedStyle(e);
    out.push({
      k,
      color: rgba(s.color),
      bg: rgba(s.backgroundColor),
      fs: s.fontSize,
      fw: s.fontWeight,
      ff: s.fontFamily,
      bc: rgba(s.borderTopColor),
      bw: s.borderTopWidth,
      bs: s.borderTopStyle,
      vis:
        s.visibility === "hidden" ||
        s.display === "none" ||
        (s.position === "absolute" && parseFloat(s.width) <= 1 && parseFloat(s.height) <= 1) ||
        s.clipPath === "inset(50%)" ||
        s.clip === "rect(0px, 0px, 0px, 0px)" ||
        e.hasAttribute("data-radix-focus-guard"),
    });
    const tag = e.tagName.toLowerCase();
    const isF =
      ["button", "input", "select", "textarea"].includes(tag) ||
      (tag === "a" && e.hasAttribute("href")) ||
      e.hasAttribute("tabindex");
    if (isF && !e.hasAttribute("data-radix-focus-guard") && e.getAttribute("type") !== "hidden" && e.getAttribute("tabindex") !== "-1")
      focusables.push([k, e]);
    k++;
  }
  const rings = {};
  let visible = 0;
  for (const [key, e] of focusables) {
    try {
      e.focus({ preventScroll: true, focusVisible: true });
    } catch {
      continue;
    }
    if (document.activeElement !== e) continue;
    if (e.matches(":focus-visible")) visible++;
    const s = getComputedStyle(e);
    let ring = null;
    if (s.outlineStyle !== "none" && parseFloat(s.outlineWidth) > 0) {
      ring = { kind: "outline", w: s.outlineWidth, c: rgba(s.outlineColor) };
    } else if (s.boxShadow && s.boxShadow !== "none") {
      const parts = s.boxShadow.split(/,(?![^(]*\))/).map((p) => p.trim());
      let best = null;
      for (const p of parts) {
        const col = (p.match(/(rgba?\([^)]*\)|oklch\([^)]*\)|oklab\([^)]*\)|lab\([^)]*\)|color\([^)]*\)|#[0-9a-f]+)/i) || [])[0];
        const nums = p.replace(col || "", "").trim().split(/\s+/).map(parseFloat);
        const spread = nums[3] || 0;
        const c = rgba(col);
        if (spread > 0 && !c.endsWith(", 0.000)") && c !== "rgba(0, 0, 0, 0)" && (!best || spread > best.spread)) best = { spread, c };
      }
      if (best) ring = { kind: "shadow", w: `${best.spread}px`, c: best.c };
    }
    rings[key] = ring || { kind: "none" };
    e.blur();
  }
  const cs = getComputedStyle(document.documentElement).colorScheme;
  const htmlBg = rgba(getComputedStyle(document.documentElement).backgroundColor);
  const loaded = [...new Set([...document.fonts].filter((f) => f.status === "loaded").map((f) => f.family.replace(/["']/g, "")))];
  return { out, rings, visible, nf: focusables.length, cs, htmlBg, loaded };
};

const browser = await chromium.launch({
  headless: true,
  ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}),
});
const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
const page = await ctx.newPage();
const root = base.replace(/\/+$/, "") + "/";
let n = 0;
const summary = [];
for (const p of pages) {
  const stem = p.replace(/^.*\//, "").replace(/\?/, "~").replace(/&?chrome=0/, "").replace(/=/g, "-").replace(/&/g, "~");
  const res = {};
  let html = "";
  for (const theme of ["light", "dark"]) {
    const url = `${root}${p.replace(/^\/+/, "")}${p.includes("?") ? "&" : "?"}theme=${theme}`;
    await page.goto(url, { waitUntil: "networkidle" });
    await page.waitForTimeout(600);
    await page.addStyleTag({ content: "*,*::before,*::after{transition:none!important;animation:none!important}" });
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(100);
    res[theme] = await page.evaluate(COLLECT);
    if (theme === "light") {
      const hid = res.light.out.filter((r) => r.vis).map((r) => r.k);
      html = await page.evaluate((hid) => {
        const d = document.documentElement.cloneNode(true);
        for (const k of hid) d.querySelector(`[data-k="${k}"]`)?.remove();
        d.querySelectorAll("script,style,link,noscript,template,nextjs-portal,svg *").forEach((x) => x.remove());
        d.querySelectorAll("[style]").forEach((x) => x.removeAttribute("style"));
        d.removeAttribute("class");
        d.removeAttribute("data-theme");
        d.removeAttribute("style");
        return d.outerHTML;
      }, hid);
    }
  }
  const L = res.light, D = res.dark;
  if (L.out.length !== D.out.length) summary.push(`${stem}: element count differs light ${L.out.length} dark ${D.out.length}`);
  const rule = (r) =>
    `color:${r.color};background-color:${r.bg};font-size:${r.fs};font-weight:${r.fw};font-family:${r.ff};border-color:${r.bc};border-width:${r.bw};border-style:${r.bs}`;
  const ringRule = (g) =>
    !g ? "" : g.kind === "none" ? "outline:none;box-shadow:none" : g.kind === "outline" ? `outline:${g.w} solid ${g.c}` : `outline:none;box-shadow:0 0 0 ${g.w} ${g.c}`;
  let css = L.loaded.map((f) => `@font-face{font-family:"${f}";src:local("${f}")}\n`).join("") + `html{color-scheme:${L.cs};background-color:${L.htmlBg}}\n`;
  let dark = `html[data-theme="dark"]{color-scheme:${D.cs};background-color:${D.htmlBg}}\n`;
  let media = `html{color-scheme:${D.cs};background-color:${D.htmlBg}}\n`;
  for (const r of L.out) css += `[data-k="${r.k}"]{${rule(r)}}\n`;
  for (const [k, g] of Object.entries(L.rings)) css += `[data-k="${k}"]:focus-visible{${ringRule(g)}}\n`;
  for (const r of D.out) {
    dark += `[data-theme="dark"] [data-k="${r.k}"]{${rule(r)}}\n`;
    media += `[data-k="${r.k}"]{${rule(r)}}\n`;
  }
  for (const [k, g] of Object.entries(D.rings)) {
    dark += `[data-theme="dark"] [data-k="${k}"]:focus-visible{${ringRule(g)}}\n`;
    media += `[data-k="${k}"]:focus-visible{${ringRule(g)}}\n`;
  }
  const doc = html.replace(/<head>/, `<head><link rel="stylesheet" href="${stem}.css">`);
  fs.writeFileSync(path.join(outDir, `${stem}.html`), "<!doctype html>\n" + doc.replace(/></g, ">\n<"));
  fs.writeFileSync(path.join(outDir, `${stem}.css`), css + dark + `@media (prefers-color-scheme: dark){\n${media}}\n`);
  summary.push(`${stem}: ${L.out.length} elements, ${L.nf} focusable, ${L.visible} matched :focus-visible`);
  n++;
}
await browser.close();
fs.writeFileSync(path.join(outDir, "_summary.txt"), summary.join("\n") + "\n");
console.log(`snapshot: ${n} of ${pages.length} pages written to ${outDir}; run pairs.py over ${path.join(outDir, "*.html")}`);
if (n !== pages.length) process.exit(1);
