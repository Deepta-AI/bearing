import { useEffect, useState, type ReactNode } from "react";
import { Link, useLocation } from "react-router";
import { scriptByName, skillByName, srcHref } from "../lib/data";
import { ORDER } from "../lib/nav";

export type Toc = { id: string; label: string }[];

/** A chapter: title, lede, an on-this-page rail with scroll position, and the files it describes. */
export function Page({
  crumb,
  title,
  lede,
  toc,
  sources,
  full,
  children,
}: {
  crumb?: ReactNode;
  title: ReactNode;
  lede?: ReactNode;
  toc?: Toc;
  sources?: string[];
  full?: boolean;
  children: ReactNode;
}) {
  const { hash, pathname } = useLocation();
  const [on, setOn] = useState("");
  useEffect(() => {
    if (hash) document.getElementById(decodeURIComponent(hash.slice(1)))?.scrollIntoView();
    else window.scrollTo(0, 0);
  }, [hash, pathname]);
  useEffect(() => {
    if (!toc?.length) return;
    const els = toc.map((t) => document.getElementById(t.id)).filter(Boolean) as HTMLElement[];
    const io = new IntersectionObserver(
      (entries) => {
        const vis = entries.filter((e) => e.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
        if (vis[0]) setOn(vis[0].target.id);
      },
      { rootMargin: "-70px 0px -65% 0px" },
    );
    els.forEach((e) => io.observe(e));
    return () => io.disconnect();
  }, [toc]);
  const aside = !full && ((toc && toc.length > 1) || (sources && sources.length > 0));
  return (
    <div className={aside ? "page" : "page full"}>
      <article>
        {crumb && <div className="crumb">{crumb}</div>}
        <h1>{title}</h1>
        {lede && <p className="lede">{lede}</p>}
        {children}
        <Pager />
      </article>
      {aside && (
        <nav className="onpage" aria-label="On this page">
          {toc && toc.length > 1 && (
            <>
              <h2>On this page</h2>
              {toc.map((t) => (
                <a key={t.id} href={`#${t.id}`} className={on === t.id ? "on" : undefined}>
                  {t.label}
                </a>
              ))}
            </>
          )}
          {sources && sources.length > 0 && (
            <div className="src">
              <h2>Source files</h2>
              {sources.map((s) => (
                <Src key={s} path={s} />
              ))}
            </div>
          )}
        </nav>
      )}
    </div>
  );
}

function Src({ path }: { path: string }) {
  const href = srcHref(path);
  return href ? <a href={href}>{path}</a> : <span className="srcpath">{path}</span>;
}

export function H2({ id, children }: { id: string; children: ReactNode }) {
  return <h2 id={id}>{children}</h2>;
}

function Pager() {
  const { pathname } = useLocation();
  const i = ORDER.findIndex((o) => o.to === pathname);
  if (i < 0) return null;
  const prev = ORDER[i - 1];
  const next = ORDER[i + 1];
  return (
    <nav className="pager" aria-label="Chapters">
      {prev && (
        <Link to={prev.to}>
          <small>Previous</small>
          {prev.label}
        </Link>
      )}
      {next && (
        <Link className="next" to={next.to}>
          <small>Next</small>
          {next.label}
        </Link>
      )}
    </nav>
  );
}

/** A code block with a copy button. */
export function Code({ children, cap }: { children: string; cap?: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="copy">
      {cap && <div className="cap">{cap}</div>}
      <pre>{children}</pre>
      <button
        type="button"
        onClick={() =>
          navigator.clipboard?.writeText(children).then(
            () => {
              setCopied(true);
              setTimeout(() => setCopied(false), 1400);
            },
            () => undefined,
          )
        }
      >
        {copied ? "Copied" : "Copy"}
      </button>
    </div>
  );
}

export function Note({ tone, title, children }: { tone?: "jade" | "signal"; title?: string; children: ReactNode }) {
  return (
    <div className={`note ${tone ?? ""}`}>
      {title && <strong>{title}</strong>}
      {children}
    </div>
  );
}

/** A skill name linking to its anatomy page; a script name linking to its page. */
export function S({ name }: { name: string }) {
  if (skillByName.has(name))
    return (
      <Link to={`/skills/${name}`}>
        <code>{name}</code>
      </Link>
    );
  if (scriptByName.has(name))
    return (
      <Link to={`/scripts/${name}`}>
        <code>{name}</code>
      </Link>
    );
  return <code>{name}</code>;
}

/** Plain text with `code` spans; a span naming a Bearing skill or a brg- script becomes a link. */
export function Rich({ text }: { text: string }) {
  const parts = text.split(/(`[^`]+`)/g);
  return (
    <>
      {parts.map((p, i) => {
        if (p.startsWith("`") && p.endsWith("`") && p.length > 2) {
          const inner = p.slice(1, -1);
          const bare = inner.split(/\s/)[0];
          if (skillByName.has(bare) || scriptByName.has(bare)) return <S key={i} name={bare} />;
          return <code key={i}>{inner}</code>;
        }
        return <span key={i}>{p.replace(/\*\*/g, "")}</span>;
      })}
    </>
  );
}

export type TreeRow = { path: string; note?: string; dir?: boolean; depth?: number };
export function Tree({ rows }: { rows: TreeRow[] }) {
  return (
    <div className="tree" role="list">
      {rows.map((r) => (
        <div className="row" role="listitem" key={r.path}>
          <span className={r.dir ? "dir" : undefined} style={{ paddingLeft: `${(r.depth ?? 0) * 1.4}em` }}>
            {r.path}
          </span>
          <span>{r.note}</span>
        </div>
      ))}
    </div>
  );
}

export function Defs({ rows }: { rows: [ReactNode, ReactNode][] }) {
  return (
    <dl className="defs">
      {rows.map(([k, v], i) => (
        <div key={i} style={{ display: "contents" }}>
          <dt>{k}</dt>
          <dd>{v}</dd>
        </div>
      ))}
    </dl>
  );
}
