import { useEffect, useMemo, useRef, useState } from "react";
import { Link, NavLink, Outlet, useLocation, useNavigate } from "react-router";
import { data } from "../lib/data";
import { NAV, ORDER } from "../lib/nav";

type Hit = { group: string; to: string; title: string; mono?: boolean; sub: string; score: number };

/** Everything search can find: skills, workflow rows, flow steps and pages. */
function buildIndex() {
  const out: (Omit<Hit, "score"> & { hay: string })[] = [];
  for (const s of data.skills)
    out.push({ group: "Skills", to: `/skills/${s.name}`, title: s.name, mono: true, sub: s.what, hay: `${s.name} ${s.what} ${s.when} ${s.phrases.join(" ")} ${s.category}`.toLowerCase() });
  data.stages.forEach((st, i) =>
    st.rows.forEach((r) =>
      out.push({ group: "Workflow", to: `/workflow/${i + 1}`, title: `${r.stage}: ${r.skill}`, sub: `${st.title}. ${r.output}`, hay: `${st.title} ${r.stage} ${r.skill} ${r.from} ${r.output} ${r.alternate}`.toLowerCase() }),
    ),
  );
  const visit = (fid: string, ftitle: string, nodes: (typeof data.flows)[number]["steps"]) => {
    for (const n of nodes) {
      if (n.kind === "step")
        out.push({ group: "Flows", to: `/flows/${fid}?step=${n.id}`, title: `${n.title}`, sub: `${ftitle}: ${n.skill}`, hay: `${ftitle} ${n.title} ${n.skill} ${n.does} ${n.alternates.map((a) => a.skill).join(" ")}`.toLowerCase() });
      else if (n.kind === "branch") n.options.forEach((o) => visit(fid, ftitle, o.steps));
    }
  };
  data.flows.forEach((f) => visit(f.id, f.title, f.steps));
  for (const sc of data.defaultFiles)
    for (const f of sc.files)
      out.push({ group: "Default files", to: `/files?scope=${sc.id}&file=${encodeURIComponent(f.path)}`, title: f.path, mono: true, sub: `${sc.title}. ${f.purpose}`, hay: `${f.path} ${sc.title} ${f.purpose} ${f.group ?? ""}`.toLowerCase() });
  for (const p of ORDER) out.push({ group: "Pages", to: p.to, title: p.label, sub: "", hay: p.label.toLowerCase() });
  return out;
}

function Search() {
  const index = useMemo(buildIndex, []);
  const [q, setQ] = useState("");
  const [open, setOpen] = useState(false);
  const [sel, setSel] = useState(0);
  const input = useRef<HTMLInputElement>(null);
  const nav = useNavigate();

  const hits = useMemo(() => {
    const terms = q.toLowerCase().trim().split(/\s+/).filter(Boolean);
    if (!terms.length) return [];
    const scored: Hit[] = [];
    for (const it of index) {
      if (!terms.every((t) => it.hay.includes(t))) continue;
      const t = it.title.toLowerCase();
      const score = (t.startsWith(terms[0]) ? 4 : 0) + (t.includes(terms[0]) ? 2 : 0) + (it.group === "Skills" ? 1 : 0);
      scored.push({ ...it, score });
    }
    scored.sort((a, b) => b.score - a.score);
    const per: Record<string, number> = {};
    return scored.filter((h) => (per[h.group] = (per[h.group] ?? 0) + 1) <= 6);
  }, [q, index]);

  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      const el = document.activeElement as HTMLElement | null;
      if (e.key === "/" && !/input|textarea/i.test(el?.tagName ?? "")) {
        e.preventDefault();
        input.current?.focus();
      }
    };
    document.addEventListener("keydown", key);
    return () => document.removeEventListener("keydown", key);
  }, []);

  const go = (h: Hit) => {
    nav(h.to);
    setOpen(false);
    setQ("");
    input.current?.blur();
  };

  let lastGroup = "";
  return (
    <div className="search" role="search">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
        <circle cx="11" cy="11" r="7" />
        <path d="m20 20-3.5-3.5" />
      </svg>
      <input
        ref={input}
        type="search"
        value={q}
        placeholder="Search skills, steps and pages"
        aria-label="Search the handbook"
        aria-expanded={open && q.length > 0}
        aria-controls="search-results"
        onChange={(e) => {
          setQ(e.target.value);
          setSel(0);
          setOpen(true);
        }}
        onFocus={() => setOpen(true)}
        onBlur={() => setTimeout(() => setOpen(false), 150)}
        onKeyDown={(e) => {
          if (e.key === "ArrowDown") {
            e.preventDefault();
            setSel((s) => Math.min(s + 1, hits.length - 1));
          } else if (e.key === "ArrowUp") {
            e.preventDefault();
            setSel((s) => Math.max(s - 1, 0));
          } else if (e.key === "Enter" && hits[sel]) go(hits[sel]);
          else if (e.key === "Escape") {
            setQ("");
            input.current?.blur();
          }
        }}
      />
      <kbd>/</kbd>
      {open && q.trim() && (
        <div className="results" id="search-results" role="listbox">
          {hits.length === 0 && <div className="none">Nothing matches "{q}". Try a stage ("verify"), a stack ("go") or a phrase ("prepare the MR").</div>}
          {hits.map((h, i) => {
            const head = h.group !== lastGroup ? <div className="g">{(lastGroup = h.group)}</div> : null;
            return (
              <div key={`${h.to}-${i}`}>
                {head}
                <a
                  href={h.to}
                  role="option"
                  aria-selected={i === sel}
                  onMouseDown={(e) => {
                    e.preventDefault();
                    go(h);
                  }}
                >
                  <b className={h.mono ? "" : "t"}>{h.title}</b>
                  {h.sub && <span>{h.sub}</span>}
                </a>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

function ThemeButton() {
  const [dark, setDark] = useState(
    () =>
      document.documentElement.dataset.theme === "dark" ||
      (!document.documentElement.dataset.theme && matchMedia("(prefers-color-scheme: dark)").matches),
  );
  return (
    <button
      type="button"
      className="icon-btn"
      aria-label={dark ? "Switch to light theme" : "Switch to dark theme"}
      onClick={() => {
        const next = dark ? "light" : "dark";
        document.documentElement.dataset.theme = next;
        try {
          localStorage.setItem("artkit-theme", next);
        } catch {
          /* private mode: the choice lasts this visit */
        }
        setDark(!dark);
      }}
    >
      {dark ? (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
        </svg>
      ) : (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
          <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" />
        </svg>
      )}
    </button>
  );
}

export default function Layout() {
  const [menu, setMenu] = useState(false);
  const { pathname } = useLocation();
  useEffect(() => {
    setMenu(false);
    window.scrollTo(0, 0);
    const main = document.getElementById("main");
    main?.focus({ preventScroll: true });
  }, [pathname]);

  return (
    <>
      <a className="skip" href="#main">
        Skip to content
      </a>
      <header className="top">
        <div className="top-in">
          <button type="button" className="icon-btn menu-btn" aria-label="Open the menu" aria-expanded={menu} onClick={() => setMenu(true)}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
              <path d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
          <Link className="brand" to="/">
            <span className="mark" aria-hidden="true">
              brg
            </span>
            Bearing
            <span className="ver">v{data.version}</span>
          </Link>
          <Search />
          <div className="tools">
            <ThemeButton />
          </div>
        </div>
      </header>
      <div className="shell">
        <nav className={menu ? "nav open" : "nav"} aria-label="Sections">
          {NAV.map((g) => (
            <div className="nav-g" key={g.title}>
              <span className="nav-t">{g.title}</span>
              {g.items.map((it) => (
                <NavLink key={it.to} to={it.to} end={it.to === "/"} className={({ isActive }) => (isActive ? "active" : "")}>
                  {it.swatch && <span className="sw" style={{ ["--c" as string]: it.swatch }} />}
                  {it.label}
                </NavLink>
              ))}
            </div>
          ))}
        </nav>
        {menu && <div className="scrim" onClick={() => setMenu(false)} />}
        <main id="main" tabIndex={-1}>
          <Outlet />
        </main>
      </div>
      <footer className="foot">
        Bearing v{data.version}. Generated from the skills in the repository; regenerate with <code>make docs</code>.
      </footer>
    </>
  );
}
