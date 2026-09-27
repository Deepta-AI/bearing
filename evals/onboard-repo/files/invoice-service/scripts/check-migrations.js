// Migrations are numbered 001, 002, ... with no gaps or duplicates.
import { readdirSync } from "node:fs";

const files = readdirSync("migrations").filter((f) => f.endsWith(".sql")).sort();
if (files.length === 0) {
  console.error("check-migrations: 0 migrations, nothing checked");
  process.exit(1);
}
let bad = 0;
files.forEach((f, i) => {
  const want = String(i + 1).padStart(3, "0");
  if (!f.startsWith(want + "_")) { console.error(`migrations/${f}: expected prefix ${want}_`); bad++; }
});
console.log(`check-migrations: ${files.length} migrations, ${bad} problems`);
process.exit(bad ? 1 : 0);
