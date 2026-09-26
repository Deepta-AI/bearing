import { CodeBlock, DocPage, type Toc } from "@ui";
import type { ReactNode } from "react";
import { Link } from "react-router";
import { packKey, packName, skillByName } from "../lib/data";

export type { Toc };

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
  return <CodeBlock copy={exact ? children : children.replace(/\s+#.*$/gm, "")}>{children}</CodeBlock>;
}

/** A page with a title, a lede and an on-this-page column built from its sections. */
export function Page(props: { crumb?: ReactNode; title: ReactNode; lede?: ReactNode; toc?: Toc; full?: boolean; children: ReactNode }) {
  return <DocPage {...props} />;
}

export function Section({ id, title, children }: { id: string; title: string; children: ReactNode }) {
  return (
    <section>
      <h2 id={id}>{title}</h2>
      {children}
    </section>
  );
}
