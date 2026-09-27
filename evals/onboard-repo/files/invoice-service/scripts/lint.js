// Minimal lint: no console.log and no tab indentation under src/.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const files = readdirSync("src").filter((f) => f.endsWith(".js"));
if (files.length === 0) {
  console.error("lint: 0 files under src/, nothing checked");
  process.exit(1);
}
let problems = 0;
for (const f of files) {
  readFileSync(join("src", f), "utf8").split("\n").forEach((line, i) => {
    if (line.includes("console.log")) { console.error(`src/${f}:${i + 1}: console.log`); problems++; }
    if (line.startsWith("\t")) { console.error(`src/${f}:${i + 1}: tab indentation`); problems++; }
  });
}
console.log(`lint: ${files.length} files, ${problems} problems`);
process.exit(problems ? 1 : 0);
