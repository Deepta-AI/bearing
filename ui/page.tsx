import { useEffect, useLayoutEffect, useRef, useState, type ReactNode } from "react";
import { Link, useLocation } from "react-router";
import { isActive, useShell } from "./shell";

export type Toc = { id: string; label: string }[];

const slug = (s: string) =>
  s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 60) || "section";

/** Give every h2 and h3 an id and a link to itself, so any heading can be linked to. */
function anchorHeadings(root: HTMLElement) {
  const seen = new Set(Array.from(document.querySelectorAll("[id]")).map((e) => e.id));
  root.querySelectorAll<HTMLHeadingElement>("h2, h3").forEach((h) => {
    if (h.closest("[data-no-anchor], .card, a, button, dialog")) return;
    if (!h.id) {
      let id = slug(h.textContent ?? "");
      for (let n = 2; seen.has(id); n++) id = `${slug(h.textContent ?? "")}-${n}`;
      h.id = id;
      seen.add(id);
    }
    const a = h.querySelector<HTMLAnchorElement>(":scope > .ui-anchor");
    if (a) {
      a.href = `#${h.id}`;
      return;
    }
    const link = document.createElement("a");
    link.className = "ui-anchor";
    link.href = `#${h.id}`;
    link.textContent = "#";
    link.setAttribute("aria-label", `Link to this section: ${(h.textContent ?? "").trim()}`);
    h.appendChild(link);
  });
}

function headingText(h: HTMLElement) {
  return Array.from(h.childNodes)
    .filter((n) => !(n instanceof HTMLElement && n.classList.contains("ui-anchor")))
    .map((n) => n.textContent)
    .join("")
    .trim();
}

/**
 * A documentation page: crumb, title, lede, content, an on-this-page list on
 * long pages (from `toc`, or from the page's own h2 headings), and previous
 * and next links in reading order.
 */
export function DocPage({
  crumb,
  title,
  lede,
  toc,
  full,
  aside,
  pager = true,
  children,
}: {
  crumb?: ReactNode;
  title?: ReactNode;
  lede?: ReactNode;
  toc?: Toc;
  full?: boolean;
  aside?: ReactNode;
  pager?: boolean | { prev: string; next: string };
  children: ReactNode;
}) {
  const art = useRef<HTMLElement>(null);
  const { pathname, hash } = useLocation();
  const [auto, setAuto] = useState<Toc>([]);
  const [on, setOn] = useState("");
  const scrolled = useRef("");

  // After every render: anchors on headings, and the automatic contents list.
  useLayoutEffect(() => {
    const el = art.current;
    if (!el) return;
    anchorHeadings(el);
    if (!toc) {
      const hs = Array.from(el.querySelectorAll<HTMLElement>(":scope > h2[id], :scope > section > h2[id], :scope > div > h2[id]"));
      const next = hs.map((h) => ({ id: h.id, label: headingText(h) }));
      if (JSON.stringify(next) !== JSON.stringify(auto)) setAuto(next);
    }
  });

  const list = toc ?? auto;

  useEffect(() => {
    const key = pathname + hash;
    if (!hash || scrolled.current === key) return;
    const id = decodeURIComponent(hash.slice(1));
    const t = requestAnimationFrame(() => {
      const el = document.getElementById(id);
      if (el) {
        el.scrollIntoView();
        scrolled.current = key;
      }
    });
    return () => cancelAnimationFrame(t);
  });

  useEffect(() => {
    if (list.length < 2) return;
    const els = list.map((t) => document.getElementById(t.id)).filter(Boolean) as HTMLElement[];
    const io = new IntersectionObserver(
      (entries) => {
        const vis = entries.filter((e) => e.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
        if (vis[0]) setOn(vis[0].target.id);
      },
      { rootMargin: "-70px 0px -65% 0px" },
    );
    els.forEach((e) => io.observe(e));
    return () => io.disconnect();
  }, [list]);

  const showToc = !full && (list.length > 2 || (list.length > 1 && !!toc) || !!aside);
  const links = list.map((t) => (
    <a key={t.id} href={`#${t.id}`} aria-current={on === t.id ? "true" : undefined}>
      {t.label}
    </a>
  ));
  return (
    <div className={showToc ? "ui-page" : "ui-page full"}>
      <article ref={art}>
        {crumb && <div className="crumb">{crumb}</div>}
        {title && <h1 data-no-anchor>{title}</h1>}
        {lede && <p className="lede">{lede}</p>}
        {showToc && list.length > 1 && (
          <details className="ui-toc-inline">
            <summary>On this page</summary>
            <nav aria-label="Contents">{links}</nav>
          </details>
        )}
        {children}
        {pager && <Pager prevLabel={typeof pager === "object" ? pager.prev : undefined} nextLabel={typeof pager === "object" ? pager.next : undefined} />}
      </article>
      {showToc && (
        <aside className="ui-toc">
          {list.length > 1 && (
            <nav aria-label="On this page">
              <span className="t">On this page</span>
              {links}
            </nav>
          )}
          {aside && <div className={list.length > 1 ? "extra" : undefined}>{aside}</div>}
        </aside>
      )}
    </div>
  );
}

export function Pager({ prevLabel = "Previous", nextLabel = "Next" }: { prevLabel?: string; nextLabel?: string }) {
  const { order } = useShell();
  const { pathname } = useLocation();
  const i = order.findIndex((p) => isActive({ ...p, prefix: false }, pathname, ""));
  if (i < 0) return null;
  const prev = order[i - 1];
  const next = order[i + 1];
  if (!prev && !next) return null;
  return (
    <nav className="ui-pager" aria-label="Previous and next page">
      {prev ? (
        <Link to={prev.to} rel="prev">
          <span>{prevLabel}</span>
          {prev.label}
        </Link>
      ) : (
        <span />
      )}
      {next && (
        <Link className="next" to={next.to} rel="next">
          <span>{nextLabel}</span>
          {next.label}
        </Link>
      )}
    </nav>
  );
}

const copyIcon = (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
    <rect x="9" y="9" width="11" height="11" rx="2" />
    <path d="M5 15V5a2 2 0 0 1 2-2h8" />
  </svg>
);
const tickIcon = (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" aria-hidden="true">
    <path d="m5 12 5 5 9-10" />
  </svg>
);

export function CopyButton({ text, label = "Copy" }: { text: string; label?: string }) {
  const [done, setDone] = useState(false);
  return (
    <button
      type="button"
      className="copy-btn"
      aria-label={done ? "Copied" : `${label} to the clipboard`}
      onClick={() =>
        navigator.clipboard?.writeText(text).then(
          () => {
            setDone(true);
            setTimeout(() => setDone(false), 1400);
          },
          () => undefined,
        )
      }
    >
      {done ? tickIcon : copyIcon}
      <span aria-live="polite">{done ? "Copied" : label}</span>
    </button>
  );
}

/** A code block with a copy button. `copy` overrides what is copied. */
export function CodeBlock({ children, cap, copy }: { children: string; cap?: string; copy?: string }) {
  return (
    <div className={cap ? "cb has-cap" : "cb"}>
      {cap && <div className="cap">{cap}</div>}
      <pre tabIndex={0}>{children}</pre>
      <CopyButton text={copy ?? children} />
    </div>
  );
}

/** One command on one line, with a prompt and a copy button. */
export function Cmd({ children, prompt = "" }: { children: string; prompt?: string }) {
  return (
    <div className="cmd">
      {prompt && <span className="p">{prompt}</span>}
      <code>{children}</code>
      <CopyButton text={children} />
    </div>
  );
}

export function Callout({ tone, title, children }: { tone?: "ok" | "warn" | "bad"; title?: string; children: ReactNode }) {
  return (
    <div className={`callout ${tone ?? ""}`}>
      {title && <strong>{title}</strong>}
      {children}
    </div>
  );
}
