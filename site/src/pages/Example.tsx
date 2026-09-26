import { Fragment, type ReactNode } from "react";
import { Page } from "../components/ui";
import { data } from "../lib/data";

/** Inline markdown: `code` and **bold**. */
function inline(s: string): ReactNode {
  return s.split(/(`[^`]+`|\*\*[^*]+\*\*)/).map((part, i) =>
    part.startsWith("`") ? <code key={i}>{part.slice(1, -1)}</code> : part.startsWith("**") ? <b key={i}>{part.slice(2, -2)}</b> : <Fragment key={i}>{part}</Fragment>,
  );
}

/** Block markdown: paragraphs, fenced code, bullet and numbered lists. Enough for a build log. */
function blocks(md: string): ReactNode[] {
  const out: ReactNode[] = [];
  const lines = md.split("\n");
  let i = 0;
  while (i < lines.length) {
    const l = lines[i];
    if (l.startsWith("```")) {
      const code: string[] = [];
      i++;
      while (i < lines.length && !lines[i].startsWith("```")) code.push(lines[i++]);
      i++;
      out.push(<pre key={out.length}>{code.join("\n")}</pre>);
    } else if (/^\s*([-*]|\d+[.)])\s+/.test(l)) {
      const ordered = /^\s*\d/.test(l);
      const items: string[] = [];
      while (i < lines.length && /^\s*([-*]|\d+[.)])\s+/.test(lines[i])) items.push(lines[i++].replace(/^\s*([-*]|\d+[.)])\s+/, ""));
      const L = ordered ? "ol" : "ul";
      out.push(<L key={out.length}>{items.map((t, k) => <li key={k}>{inline(t)}</li>)}</L>);
    } else if (/^#{1,6}\s/.test(l)) {
      out.push(<h4 key={out.length}>{inline(l.replace(/^#+\s/, ""))}</h4>);
      i++;
    } else if (l.trim()) {
      const para: string[] = [];
      while (i < lines.length && lines[i].trim() && !/^(```|#|\s*([-*]|\d+[.)])\s)/.test(lines[i])) para.push(lines[i++].trim());
      out.push(<p key={out.length}>{inline(para.join(" "))}</p>);
    } else i++;
  }
  return out;
}

export default function Example() {
  const md = data.walkthrough;
  if (!md)
    return (
      <Page title="A recorded task" lede="No recording yet.">
        <div className="empty">docs/examples/walkthrough.md is rendered here by make docs once it exists.</div>
      </Page>
    );
  const [intro, ...rest] = md.split(/^## /m);
  const steps = rest.map((chunk) => {
    const nl = chunk.indexOf("\n");
    return { title: chunk.slice(0, nl).trim(), body: chunk.slice(nl + 1) };
  });
  const introText = intro.replace(/^# .*\n/, "");
  return (
    <Page
      title="A recorded task"
      lede="A real build, captured prompt by prompt: what the developer typed and what each skill reported, unchanged. Open a step to read it."
    >
      <div className="muted">{blocks(introText)}</div>
      {steps.map((s, i) => {
        const m = s.title.match(/^Step\s+(\d+):?\s*(.*)$/i);
        return (
          <details className="walk-step" key={i} open={i === 0}>
            <summary>
              <i>{m ? m[1] : i + 1}</i>
              {m ? m[2] : s.title}
            </summary>
            <div className="body">{blocks(s.body)}</div>
          </details>
        );
      })}
    </Page>
  );
}
