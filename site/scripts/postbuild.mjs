// GitLab Pages has no SPA rewrite: a deep link like /skills/branch-review is
// answered with 404.html, so 404.html is the app. The count guards the build:
// a site with zero skills or zero flows in its data did not build anything.
import { copyFileSync, readFileSync } from "node:fs";
const data = JSON.parse(readFileSync(new URL("../src/data/handbook.json", import.meta.url)));
const skills = data.skills?.length ?? 0, flows = data.flows?.length ?? 0;
if (!skills || !flows) { console.error(`handbook: ${skills} skills, ${flows} flows in the data, nothing built`); process.exit(1); }
copyFileSync(new URL("../dist/index.html", import.meta.url), new URL("../dist/404.html", import.meta.url));
console.log(`handbook: built with ${skills} skills, ${flows} flows; dist/404.html written`);
