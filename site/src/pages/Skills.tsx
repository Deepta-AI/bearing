import { useMemo, useState } from "react";
import { Link } from "react-router";
import { Page } from "../components/ui";
import { data } from "../lib/data";
import { catLabel, catSlug } from "../lib/nav";

export default function Skills() {
  const [cat, setCat] = useState("all");
  const [inv, setInv] = useState<"all" | "command" | "auto">("all");
  const [plug, setPlug] = useState("all");
  const shown = useMemo(
    () =>
      data.skills.filter(
        (s) =>
          (cat === "all" || s.category === cat) &&
          (inv === "all" || s.invocation === inv) &&
          (plug === "all" || (s.plugin ?? "bearing") === plug),
      ),
    [cat, inv, plug],
  );
  const groups = data.categories.map((c) => ({ c, items: shown.filter((s) => s.category === c) })).filter((g) => g.items.length);
  const plugins = [...new Set(data.skills.map((s) => s.plugin ?? "bearing"))];
  return (
    <Page
      full
      title="The Bearing skills"
      lede="Every skill the kit ships, grouped by the part of the work it serves. Ask for one in your own words or type it as /<plugin>:<name>. Open one for when to use it, the phrases that trigger it and where it fits in the workflow."
    >
      <div className="filters">
        {["all", ...data.categories].map((c) => (
          <button key={c} type="button" className={`chip${cat === c ? " on" : ""}`} onClick={() => setCat(c)}>
            {c === "all" ? "All" : catLabel(c)}
          </button>
        ))}
        {/* Only a skill hidden from the model is typed-only; show the filter when one exists. */}
        {data.skills.some((s) => s.invocation === "command") && (
          <label className="sel" style={{ marginLeft: "auto" }}>
            Runs
            <select value={inv} onChange={(e) => setInv(e.target.value as typeof inv)}>
              <option value="all">either way</option>
              <option value="command">only when typed</option>
              <option value="auto">on request too</option>
            </select>
          </label>
        )}
        <label className="sel" style={data.skills.some((s) => s.invocation === "command") ? undefined : { marginLeft: "auto" }}>
          Plugin
          <select value={plug} onChange={(e) => setPlug(e.target.value)}>
            <option value="all">any</option>
            {plugins.map((v) => (
              <option key={v} value={v}>
                {v}
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
          <h2 className="cat-h" id={catSlug(g.c)}>
            {catLabel(g.c)}
            <span className="n">{g.items.length}</span>
          </h2>
          <div className="cat-list">
            {g.items.map((s) => {
              return (
                <Link className="item" key={s.name} to={`/skills/${s.name}`}>
                  <div className="head">
                    <span className="skillname">{s.name}</span>
                    {s.plugin && s.plugin !== "bearing" && <span className="tag">{s.plugin}</span>}
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
