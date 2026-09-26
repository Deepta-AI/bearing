import { useMemo, useState } from "react";
import { Link } from "react-router";
import { Page } from "../components/ui";
import { data, invokeName, type Comparison, type Verdict } from "../lib/data";

const verdictShort: Record<Verdict, string> = {
  "bearing-stronger": "stronger than the alternative",
  "alternative-stronger": "use the alternative",
  "different-job": "different job",
  "no-alternative": "no alternative",
  unverified: "alternative not installed",
};

/** The verdict in a few words, naming the alternative it was judged against. */
function short(c: Comparison) {
  const alt = c.best_alternative && (c.best_alternative.invoke ?? invokeName(c.best_alternative.name, c.best_alternative.pack));
  if (c.verdict === "bearing-stronger" && alt) return `beats ${alt}`;
  if (c.verdict === "alternative-stronger" && alt) return `use ${alt}`;
  if (c.verdict === "different-job" && alt) return `differs from ${alt}`;
  if (c.verdict === "unverified" && alt) return `${alt} not installed`;
  return verdictShort[c.verdict];
}

export default function Skills() {
  const [cat, setCat] = useState("all");
  const [inv, setInv] = useState<"all" | "command" | "auto">("all");
  const [ver, setVer] = useState<"all" | Verdict>("all");
  const shown = useMemo(
    () =>
      data.skills.filter(
        (s) =>
          (cat === "all" || s.category === cat) &&
          (inv === "all" || s.invocation === inv) &&
          (ver === "all" || data.comparisons[s.name]?.verdict === ver),
      ),
    [cat, inv, ver],
  );
  const groups = data.categories.map((c) => ({ c, items: shown.filter((s) => s.category === c) })).filter((g) => g.items.length);
  const verdicts = (["bearing-stronger", "different-job", "no-alternative", "unverified", "alternative-stronger"] as Verdict[]).filter((v) =>
    Object.values(data.comparisons).some((c) => c.verdict === v),
  );
  return (
    <Page
      full
      title="The Bearing skills"
      lede="Every skill the kit ships, grouped by the part of the work it serves. Open one for when to use it, the phrases that trigger it, and how it compares with the best alternative installed."
    >
      <div className="filters">
        {["all", ...data.categories].map((c) => (
          <button key={c} type="button" className={`chip${cat === c ? " on" : ""}`} onClick={() => setCat(c)}>
            {c === "all" ? "All" : c === "genai" ? "GenAI" : c}
          </button>
        ))}
        <label className="sel" style={{ marginLeft: "auto" }}>
          Runs
          <select value={inv} onChange={(e) => setInv(e.target.value as typeof inv)}>
            <option value="all">either way</option>
            <option value="command">when you type it</option>
            <option value="auto">on its own</option>
          </select>
        </label>
        <label className="sel">
          Verdict
          <select value={ver} onChange={(e) => setVer(e.target.value as typeof ver)}>
            <option value="all">any</option>
            {verdicts.map((v) => (
              <option key={v} value={v}>
                {verdictShort[v]}
              </option>
            ))}
          </select>
        </label>
        <span className="count">
          {shown.length} of {data.skills.length}
        </span>
      </div>
      {groups.length === 0 && <div className="empty">No skill matches these filters. Clear one to see more.</div>}
      {groups.map((g) => (
        <section key={g.c}>
          <h2 className="cat-h" id={g.c}>
            {g.c}
            <span>{g.items.length}</span>
          </h2>
          <div className="cat-list">
            {g.items.map((s) => {
              const c = data.comparisons[s.name];
              return (
                <Link className="item" key={s.name} to={`/skills/${s.name}`}>
                  <div className="head">
                    <span className="skillname">{s.name}</span>
                    {c && <span className={`tag v ${c.verdict}`}>{short(c)}</span>}
                  </div>
                  <p>{s.what}.</p>
                </Link>
              );
            })}
          </div>
        </section>
      ))}
    </Page>
  );
}
