import { useEffect, useMemo, useState } from "react";
import { Link, useLocation } from "react-router";
import { Page } from "../components/ui";
import { data } from "../lib/data";
import { catLabel, catSlug } from "../lib/nav";

export default function Skills() {
  const [cat, setCat] = useState("all");
  const [inv, setInv] = useState<"all" | "command" | "auto">("all");
  const [plug, setPlug] = useState("all");
  const { hash } = useLocation();
  // A sidebar link to /skills#<category> must land on its heading, so it clears the filters.
  useEffect(() => {
    if (hash) {
      setCat("all");
      setInv("all");
      setPlug("all");
    }
  }, [hash]);
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
  const inCat = (c: string) => data.skills.filter((s) => c === "all" || s.category === c).length;
  // Only a skill hidden from the model is typed-only; show that filter when one exists.
  const hasTyped = data.skills.some((s) => s.invocation === "command");
  return (
    <Page
      full
      crumb="Skills"
      title="The Bearing skills"
      lede="Every skill the kit ships, grouped by the part of the work it serves. Ask for one in your own words, or type /<plugin>:<name>. Open a skill to see when to use it and where it fits."
    >
      <div className="filters">
        <div className="tabs" role="group" aria-label="Category">
          {["all", ...data.categories].map((c) => (
            <button key={c} type="button" aria-pressed={cat === c} onClick={() => setCat(c)}>
              {c === "all" ? "All" : catLabel(c)}
              <span className="count">{inCat(c)}</span>
            </button>
          ))}
        </div>
        <div className="filter-row">
          <div className="seg" role="group" aria-label="Plugin">
            {["all", ...plugins].map((v) => (
              <button key={v} type="button" aria-pressed={plug === v} onClick={() => setPlug(v)}>
                {v === "all" ? "Any plugin" : v}
              </button>
            ))}
          </div>
          {hasTyped && (
            <div className="seg" role="group" aria-label="Runs">
              {(
                [
                  ["all", "Either way"],
                  ["command", "Only when typed"],
                  ["auto", "On request too"],
                ] as const
              ).map(([v, label]) => (
                <button key={v} type="button" aria-pressed={inv === v} onClick={() => setInv(v)}>
                  {label}
                </button>
              ))}
            </div>
          )}
          <span className="shown" aria-live="polite">
            {shown.length} of {data.skills.length}
          </span>
        </div>
      </div>
      {groups.length === 0 && <div className="empty">No skill matches these filters. Clear one to see more.</div>}
      {groups.map((g) => (
        <section key={g.c}>
          <h2 className="cat-h" id={catSlug(g.c)}>
            {catLabel(g.c)}
            <span className="n">{g.items.length}</span>
          </h2>
          <div className="cat-list">
            {g.items.map((s) => (
              <Link className="item" key={s.name} to={`/skills/${s.name}`}>
                <div className="head">
                  <span className="skillname">{s.name}</span>
                  {s.plugin && s.plugin !== "bearing" && <span className="tag">{s.plugin}</span>}
                </div>
                <p>{s.what}.</p>
              </Link>
            ))}
          </div>
        </section>
      ))}
    </Page>
  );
}
