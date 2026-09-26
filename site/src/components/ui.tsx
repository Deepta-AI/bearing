import { useEffect, useState, type ReactNode } from "react";
import { Link, useLocation } from "react-router";
import { packKey, packName, skillByName } from "../lib/data";
import { ORDER } from "../lib/nav";

/** A skill name: a link to its page when it is a Bearing skill, plain otherwise. */
export function SkillLink({ name, className = "skillname" }: { name: string; className?: string }) {
  const bare = name.split(" ")[0];
  if (skillByName.has(bare)) {
    return (
      <Link className={className} to={`/skills/${bare}`}>
        {name}
      </Link>
    );
  }
  return <code className={className}>{name}</code>;
}

export function PackTag({ pack }: { pack: string }) {
  return <span className={`tag dot c-${packKey(pack)}`}>{packName(pack)}</span>;
}

/** A code block with a copy button. Commands drop their trailing # notes when copied; `exact` copies a file as it is. */
export function Code({ children, exact }: { children: string; exact?: boolean }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="copy">
      <pre>{children}</pre>
      <button
        type="button"
        onClick={() => {
          navigator.clipboard?.writeText(exact ? children : children.replace(/\s+#.*$/gm, "")).then(
            () => {
              setCopied(true);
              setTimeout(() => setCopied(false), 1400);
            },
            () => undefined,
          );
        }}
      >
        {copied ? "Copied" : "Copy"}
      </button>
    </div>
  );
}

export type Toc = { id: string; label: string }[];

/** A page with a title, a lede and an on-this-page column built from its sections. */
export function Page({
  crumb,
  title,
  lede,
  toc,
  full,
  children,
}: {
  crumb?: ReactNode;
  title: ReactNode;
  lede?: ReactNode;
  toc?: Toc;
  full?: boolean;
  children: ReactNode;
}) {
  const { hash } = useLocation();
  useEffect(() => {
    if (hash) document.getElementById(decodeURIComponent(hash.slice(1)))?.scrollIntoView();
  }, [hash]);
  const aside = !full && toc && toc.length > 1;
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
          <b>On this page</b>
          {toc.map((t) => (
            <a key={t.id} href={`#${t.id}`}>
              {t.label}
            </a>
          ))}
        </nav>
      )}
    </div>
  );
}


function Pager() {
  const { pathname } = useLocation();
  const i = ORDER.findIndex((p) => p.to === pathname);
  if (i < 0) return null;
  const prev = ORDER[i - 1];
  const next = ORDER[i + 1];
  return (
    <nav className="pager" aria-label="Previous and next page">
      {prev ? (
        <Link to={prev.to}>
          <span>Previous</span>
          {prev.label}
        </Link>
      ) : (
        <span />
      )}
      {next && (
        <Link className="next" to={next.to}>
          <span>Next</span>
          {next.label}
        </Link>
      )}
    </nav>
  );
}

export function Section({ id, title, children }: { id: string; title: string; children: ReactNode }) {
  return (
    <section>
      <h2 id={id}>{title}</h2>
      {children}
    </section>
  );
}
