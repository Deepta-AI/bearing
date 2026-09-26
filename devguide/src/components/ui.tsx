import { Callout, CodeBlock, DocPage, type Toc } from "@ui";
import type { ReactNode } from "react";
import { Link } from "react-router";
import { scriptByName, skillByName, srcHref } from "../lib/data";

export type { Toc };

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
  const aside =
    sources && sources.length > 0 ? (
      <div className="src">
        <span className="t">Source files</span>
        {sources.map((s) => (
          <Src key={s} path={s} />
        ))}
      </div>
    ) : undefined;
  return (
    <DocPage crumb={crumb} title={title} lede={lede} toc={toc} full={full} aside={aside}>
      {children}
    </DocPage>
  );
}

function Src({ path }: { path: string }) {
  const href = srcHref(path);
  return href ? <a href={href}>{path}</a> : <span className="srcpath">{path}</span>;
}

export function H2({ id, children }: { id: string; children: ReactNode }) {
  return <h2 id={id}>{children}</h2>;
}

/** A code block with a copy button. */
export function Code({ children, cap }: { children: string; cap?: string }) {
  return <CodeBlock cap={cap}>{children}</CodeBlock>;
}

export function Note({ tone, title, children }: { tone?: "jade" | "signal"; title?: string; children: ReactNode }) {
  return (
    <Callout tone={tone === "jade" ? "ok" : tone === "signal" ? "bad" : "warn"} title={title}>
      {children}
    </Callout>
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
