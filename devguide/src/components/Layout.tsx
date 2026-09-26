import { useEffect, useMemo, useRef, useState } from "react";
import { Link, NavLink, Outlet, useLocation, useNavigate } from "react-router";
import { data } from "../lib/data";
import { NAV } from "../lib/nav";

type Item = { group: string; to: string; title: string; sub: string; hay: string };

function buildIndex(): Item[] {
  const out: Item[] = [];
  for (const g of NAV) for (const p of g.items) out.push({ group: "Chapters", to: p.to, title: p.label, sub: "", hay: p.label.toLowerCase() });
  for (const s of data.scripts.filter((x) => x.group !== "skill"))
    out.push({ group: "Scripts", to: `/scripts/${s.name}`, title: s.path, sub: s.header.split("\n")[0], hay: `${s.path} ${s.header} ${s.functions.join(" ")} ${s.env.join(" ")}`.toLowerCase() });
  for (const s of data.skills) out.push({ group: "Skills", to: `/skills/${s.name}`, title: s.name, sub: s.what, hay: `${s.name} ${s.description} ${s.category}`.toLowerCase() });
  for (const a of data.agents) out.push({ group: "Agents", to: `/agents#${a.name}`, title: a.name, sub: a.description, hay: `${a.name} ${a.description}`.toLowerCase() });
  for (const m of data.make) out.push({ group: "Make targets", to: `/gates#make`, title: `make ${m.name}`, sub: m.does, hay: `make ${m.name} ${m.does}`.toLowerCase() });
  for (const t of data.tests) out.push({ group: "Tests", to: `/gates#tests`, title: t.path, sub: t.header.slice(0, 120), hay: `${t.path} ${t.header}`.toLowerCase() });
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
    const scored = index
      .filter((it) => terms.every((t) => it.hay.includes(t) || it.title.toLowerCase().includes(t)))
      .map((it) => ({ it, score: (it.title.toLowerCase().includes(terms[0]) ? 4 : 0) + (it.group === "Chapters" ? 2 : 0) + (it.group === "Scripts" ? 1 : 0) }));
    scored.sort((a, b) => b.score - a.score);
    const per: Record<string, number> = {};
    return scored.map((s) => s.it).filter((h) => (per[h.group] = (per[h.group] ?? 0) + 1) <= 5);
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
  const go = (h: Item) => {
    nav(h.to);
    setOpen(false);
    setQ("");
    input.current?.blur();
  };
  let lastGroup = "";
  return (
    <div className="search" role="search">
      <input
        ref={input}
        type="search"
        value={q}
        placeholder="Search scripts, skills, targets"
        aria-label="Search the guide"
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
        <div className="results" role="listbox">
          {hits.length === 0 && <div className="none">Nothing matches "{q}". Try a script (guard), a hook event (Stop) or a variable (BEARING_TRACKER).</div>}
          {hits.map((h, i) => {
            const head = h.group !== lastGroup ? <div className="g">{(lastGroup = h.group)}</div> : null;
            return (
              <div key={`${h.to}-${h.title}`}>
                {head}
                <a
                  href={h.to}
                  className={i === sel ? "sel" : undefined}
                  role="option"
                  aria-selected={i === sel}
                  onMouseDown={(e) => {
                    e.preventDefault();
                    go(h);
                  }}
                >
                  {h.title}
                  {h.sub && <small>{h.sub}</small>}
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
  const [theme, setTheme] = useState<string>(() => document.documentElement.dataset.theme ?? "auto");
  const next = theme === "auto" ? "dark" : theme === "dark" ? "light" : "auto";
  return (
    <button
      type="button"
      className="iconbtn"
      aria-label={`Colour theme: ${theme}. Switch to ${next}`}
      onClick={() => {
        if (next === "auto") delete document.documentElement.dataset.theme;
        else document.documentElement.dataset.theme = next;
        try {
          if (next === "auto") localStorage.removeItem("bearing-internals-theme");
          else localStorage.setItem("bearing-internals-theme", next);
        } catch {
          /* private window: the choice lasts this visit */
        }
        setTheme(next);
      }}
    >
      {theme === "auto" ? "Auto" : theme === "dark" ? "Night" : "Day"}
    </button>
  );
}

export function Mark() {
  return (
    <svg viewBox="0 0 32 32" aria-hidden="true">
      <circle cx="16" cy="16" r="15" fill="none" stroke="currentColor" strokeWidth="1.5" />
      <path d="M16 4.5l3.2 11.5L16 27.5l-3.2-11.5z" fill="var(--brass)" />
      <path d="M16 16l3.2 0L16 27.5l-3.2-11.5z" fill="currentColor" opacity=".35" />
      <circle cx="16" cy="16" r="2" fill="currentColor" />
    </svg>
  );
}

export default function Layout() {
  const [open, setOpen] = useState(false);
  const { pathname } = useLocation();
  useEffect(() => setOpen(false), [pathname]);
  useEffect(() => {
    const t = NAV.flatMap((g) => g.items).find((i) => i.to === pathname)?.label ?? (/^\/(skills|scripts)\/./.test(pathname) ? decodeURIComponent(pathname.split("/").pop() ?? "") : undefined);
    document.title = t && pathname !== "/" ? `${t} · Bearing internals` : "Bearing internals";
  }, [pathname]);
  return (
    <>
      <a href="#main" className="skip">
        Skip to content
      </a>
      <header className="top">
        <button type="button" className="iconbtn menubtn" aria-expanded={open} aria-controls="side" onClick={() => setOpen((o) => !o)}>
          Menu
        </button>
        <Link to="/" className="brand">
          <Mark />
          Bearing <small>internals</small>
        </Link>
        <span className="spacer" />
        <Search />
        <ThemeButton />
      </header>
      <div className="shell">
        <nav id="side" className={open ? "side open" : "side"} aria-label="Chapters">
          {NAV.map((g) => (
            <div key={g.title}>
              <h2>{g.title}</h2>
              {g.items.map((it) => (
                <NavLink key={it.to} to={it.to} end={it.to === "/"} className={({ isActive }) => (isActive ? "active" : undefined)}>
                  {it.n !== undefined && <span className="n">{it.n}</span>}
                  {it.label}
                </NavLink>
              ))}
            </div>
          ))}
          <p className="ver">
            Bearing {data.version}. Built from the kit's own files by <code>bin/gen-devguide.py</code>.
          </p>
        </nav>
        <main id="main">
          <Outlet />
        </main>
      </div>
    </>
  );
}
