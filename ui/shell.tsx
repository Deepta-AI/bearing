import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import { Link, Outlet, useLocation } from "react-router";
import { Palette, SearchIcon, useSearchHotkeys, type SearchItem } from "./search";

export type NavItem = { to: string; label: string; n?: string; swatch?: string; also?: string[]; prefix?: boolean };
export type NavGroup = { title: string; items: NavItem[] };
export type Site = "handbook" | "devguide";

const SITES: { id: Site; label: string }[] = [
  { id: "handbook", label: "Handbook" },
  { id: "devguide", label: "Developer guide" },
];

/** Where the other site lives. Set VITE_HANDBOOK_URL and VITE_DEVGUIDE_URL at build time. */
function siteHref(id: Site): string {
  const env = import.meta.env as Record<string, string | undefined>;
  const url = id === "handbook" ? env.VITE_HANDBOOK_URL : env.VITE_DEVGUIDE_URL;
  return url || `https://github.com/Deepta-AI/bearing/tree/main/${id === "handbook" ? "site" : "devguide"}`;
}

export function isActive(it: NavItem, pathname: string, hash: string) {
  if (it.to.includes("#")) return `${pathname}${hash}` === it.to;
  if (pathname === it.to || it.also?.includes(pathname)) return true;
  return !!it.prefix && pathname.startsWith(`${it.to}/`);
}

/** The reading order: every navigation item that is its own page. */
export function readingOrder(nav: NavGroup[]) {
  return nav.flatMap((g) => g.items).filter((i) => !i.to.includes("#"));
}

const ShellCtx = createContext<{ order: NavItem[] }>({ order: [] });
export const useShell = () => useContext(ShellCtx);

export function Mark() {
  return (
    <svg viewBox="0 0 32 32" aria-hidden="true">
      <circle cx="16" cy="16" r="14.5" fill="none" stroke="currentColor" strokeWidth="1.6" />
      <path d="M16 4.8l3.4 11.2L16 27.2l-3.4-11.2z" fill="var(--accent)" />
      <path d="M16 16h3.4L16 27.2l-3.4-11.2z" fill="currentColor" opacity=".32" />
      <circle cx="16" cy="16" r="1.9" fill="currentColor" />
    </svg>
  );
}

const THEME_KEY = "bearing-theme";

function ThemeToggle() {
  const sysDark = () => matchMedia("(prefers-color-scheme: dark)").matches;
  const [dark, setDark] = useState(() => {
    const t = document.documentElement.dataset.theme;
    return t ? t === "dark" : sysDark();
  });
  useEffect(() => {
    const mq = matchMedia("(prefers-color-scheme: dark)");
    const f = () => {
      if (!document.documentElement.dataset.theme) setDark(mq.matches);
    };
    mq.addEventListener("change", f);
    return () => mq.removeEventListener("change", f);
  }, []);
  return (
    <button
      type="button"
      className="ui-icon"
      aria-label={dark ? "Use the light theme" : "Use the dark theme"}
      title={dark ? "Light theme" : "Dark theme"}
      onClick={() => {
        const next = dark ? "light" : "dark";
        // Choosing what the system already shows goes back to following it.
        const follow = (next === "dark") === sysDark();
        if (follow) delete document.documentElement.dataset.theme;
        else document.documentElement.dataset.theme = next;
        try {
          if (follow) localStorage.removeItem(THEME_KEY);
          else localStorage.setItem(THEME_KEY, next);
        } catch {
          /* private window: the choice lasts this visit */
        }
        setDark(!dark);
      }}
    >
      {dark ? (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
        </svg>
      ) : (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
          <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" />
        </svg>
      )}
    </button>
  );
}

function SiteSwitch({ site, className, label }: { site: Site; className: string; label: string }) {
  return (
    <nav className={className} aria-label={label}>
      {SITES.map((s) =>
        s.id === site ? (
          <Link key={s.id} to="/" aria-current="page">
            {s.label}
          </Link>
        ) : (
          <a key={s.id} href={siteHref(s.id)}>
            {s.label}
          </a>
        ),
      )}
    </nav>
  );
}

const chevron = (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" aria-hidden="true">
    <path d="m6 9 6 6 6-6" />
  </svg>
);

function NavGroups({ nav }: { nav: NavGroup[] }) {
  const { pathname, hash } = useLocation();
  const [closed, setClosed] = useState<Record<string, boolean>>({});
  return (
    <>
      {nav.map((g, gi) => {
        const hashHit = g.items.some((it) => it.to.includes("#") && isActive(it, pathname, hash));
        const on = (it: NavItem) => isActive(it, pathname, hash) && (it.to.includes("#") || !hashHit);
        const has = g.items.some(on);
        const shut = closed[g.title] && !has;
        const id = `navg-${gi}`;
        return (
          <div className="ui-nav-g" key={g.title}>
            <button type="button" className="ui-nav-t" aria-expanded={!shut} aria-controls={id} onClick={() => setClosed((c) => ({ ...c, [g.title]: !shut }))}>
              {g.title}
              {chevron}
            </button>
            <div id={id} hidden={shut}>
              {g.items.map((it) => (
                <Link key={it.to} to={it.to} aria-current={on(it) ? "page" : undefined}>
                  {it.n !== undefined && <span className="n">{it.n}</span>}
                  {it.swatch && <span className="sw" style={{ ["--c" as string]: it.swatch }} />}
                  {it.label}
                </Link>
              ))}
            </div>
          </div>
        );
      })}
    </>
  );
}

/** The frame both sites share: header with the site switch and search, grouped navigation, content, footer. */
export function Shell({
  site,
  version,
  nav,
  search,
  quick,
  searchPlaceholder,
  searchEmpty,
  navFoot,
  footer,
}: {
  site: Site;
  version: string;
  nav: NavGroup[];
  search: () => SearchItem[];
  quick: SearchItem[];
  searchPlaceholder: string;
  searchEmpty: string;
  navFoot?: ReactNode;
  footer: ReactNode;
}) {
  const [menu, setMenu] = useState(false);
  const { pathname, hash, search: qs } = useLocation();
  // ?search=term opens search with the term typed, so a search can be linked to.
  const initial = new URLSearchParams(qs).get("search") ?? "";
  const [finding, setFinding] = useState(!!initial);
  const open = useCallback(() => setFinding(true), []);
  useSearchHotkeys(open);

  const wasOpen = useRef(false);
  useEffect(() => {
    wasOpen.current = false;
    setMenu(false);
    if (!hash) window.scrollTo(0, 0);
    document.getElementById("main")?.focus({ preventScroll: true });
  }, [pathname, hash]);

  useEffect(() => {
    if (!menu) {
      // Closing the drawer puts focus back on the button that opened it.
      if (wasOpen.current && matchMedia("(max-width: 899px)").matches) document.querySelector<HTMLElement>(".ui-menu")?.focus();
      wasOpen.current = false;
      return;
    }
    wasOpen.current = true;
    const k = (e: KeyboardEvent) => e.key === "Escape" && setMenu(false);
    document.addEventListener("keydown", k);
    document.querySelector<HTMLElement>(".ui-nav.open a, .ui-nav.open button")?.focus();
    return () => document.removeEventListener("keydown", k);
  }, [menu]);

  const order = readingOrder(nav);
  const name = site === "handbook" ? "Handbook" : "Developer guide";
  useEffect(() => {
    const it = order.find((i) => isActive({ ...i, prefix: false }, pathname, ""));
    const sub = !it && order.some((i) => isActive(i, pathname, "")) ? decodeURIComponent(pathname.split("/").pop() ?? "") : "";
    const label = it && pathname !== "/" ? it.label : sub;
    document.title = label ? `${label} | Bearing ${name.toLowerCase()}` : `Bearing ${name.toLowerCase()}`;
  }, [pathname, order, name]);

  return (
    <ShellCtx.Provider value={{ order }}>
      <a className="skip" href="#main">
        Skip to content
      </a>
      <header className="ui-top">
        <div className="ui-top-in">
          <button type="button" className="ui-icon ui-menu" aria-label="Open the navigation" aria-expanded={menu} aria-controls="ui-nav" onClick={() => setMenu(true)}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
              <path d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
          <Link className="ui-brand" to="/" aria-label={`Bearing ${name}, home`}>
            <Mark />
            Bearing
            <span className="ver">v{version}</span>
          </Link>
          <SiteSwitch site={site} className="ui-switch" label="Bearing documentation" />
          <span className="grow" />
          <button type="button" className="ui-searchbtn" onClick={open} aria-label="Search (press / or Ctrl K)">
            <SearchIcon />
            <span className="lbl">Search</span>
            <kbd>/</kbd>
            <kbd>Ctrl K</kbd>
          </button>
          <ThemeToggle />
          <a className="ui-icon gh" href="https://github.com/Deepta-AI/bearing" aria-label="Bearing on GitHub" title="Source on GitHub">
            <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M12 .5a11.5 11.5 0 0 0-3.64 22.41c.58.1.79-.25.79-.56v-2c-3.2.7-3.88-1.37-3.88-1.37-.52-1.33-1.28-1.69-1.28-1.69-1.05-.72.08-.7.08-.7 1.16.08 1.77 1.19 1.77 1.19 1.03 1.77 2.7 1.26 3.36.96.1-.75.4-1.26.73-1.55-2.55-.29-5.24-1.28-5.24-5.69 0-1.26.45-2.29 1.19-3.1-.12-.29-.52-1.46.11-3.05 0 0 .97-.31 3.17 1.18a11 11 0 0 1 5.77 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.59.23 2.76.11 3.05.74.81 1.19 1.84 1.19 3.1 0 4.42-2.7 5.4-5.26 5.68.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.56A11.5 11.5 0 0 0 12 .5z" />
            </svg>
          </a>
        </div>
      </header>
      <div className="ui-shell">
        <nav id="ui-nav" className={menu ? "ui-nav open" : "ui-nav"} aria-label={`${name} sections`}>
          <div className="drawer-head">
            <span className="ui-brand">
              <Mark />
              Bearing
            </span>
            <button type="button" className="ui-icon" aria-label="Close the navigation" onClick={() => setMenu(false)}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
                <path d="M6 6l12 12M18 6 6 18" />
              </svg>
            </button>
          </div>
          <SiteSwitch site={site} className="ui-switch nav-switch" label="Switch documentation" />
          <NavGroups nav={nav} />
          {navFoot && <div className="foot">{navFoot}</div>}
        </nav>
        {menu && <div className="ui-scrim" onClick={() => setMenu(false)} />}
        <main id="main" tabIndex={-1}>
          <Outlet />
        </main>
      </div>
      <footer className="ui-foot">
        <div>{footer}</div>
      </footer>
      <Palette
        open={finding}
        onClose={() => setFinding(false)}
        items={search}
        quick={quick}
        placeholder={searchPlaceholder}
        empty={searchEmpty}
        initial={initial}
      />
    </ShellCtx.Provider>
  );
}
