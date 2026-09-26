// A deep link like /scripts/brg-guard must load the app on any static host:
// Vercel rewrites every path to index.html (public/vercel.json), and a host
// without rewrites answers with 404.html, so 404.html is the app too. The
// counts guard the build: a guide whose data holds zero skills, scripts or
// recordings documented nothing.
import { copyFileSync, readFileSync } from "node:fs";
const d = JSON.parse(readFileSync(new URL("../src/data/internals.json", import.meta.url)));
const r = JSON.parse(readFileSync(new URL("../src/data/recordings.json", import.meta.url)));
const skills = d.skills?.length ?? 0, scripts = d.scripts?.length ?? 0, hooks = d.hooks?.length ?? 0, recs = Object.keys(r).length;
if (!skills || !scripts || !hooks || !recs) {
  console.error(`devguide: ${skills} skills, ${scripts} scripts, ${hooks} hooks, ${recs} recordings in the data, nothing built`);
  process.exit(1);
}
copyFileSync(new URL("../dist/index.html", import.meta.url), new URL("../dist/404.html", import.meta.url));
console.log(`devguide: built with ${skills} skills, ${scripts} scripts, ${hooks} hooks, ${recs} recordings; dist/404.html written`);
