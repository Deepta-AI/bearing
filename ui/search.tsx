import { useEffect, useId, useMemo, useRef, useState } from "react";
import { useNavigate } from "react-router";

/** One thing search can find. `hay` is extra text to match that is not shown. */
export type SearchItem = { group: string; title: string; to: string; sub?: string; hay?: string; mono?: boolean; where?: string };

type Indexed = SearchItem & { t: string; h: string };

const norm = (s: string) => s.toLowerCase().normalize("NFKD").replace(/[̀-ͯ]/g, "");

/** Every term must appear; titles that start with or contain the first term rank first. */
export function rank(index: Indexed[], q: string, perGroup = 6): Indexed[] {
  const terms = norm(q).trim().split(/\s+/).filter(Boolean);
  if (!terms.length) return [];
  const out: { it: Indexed; score: number }[] = [];
  for (const it of index) {
    if (!terms.every((t) => it.h.includes(t))) continue;
    const first = terms[0];
    let score = 0;
    if (it.t === q.toLowerCase().trim()) score += 100;
    if (it.t.startsWith(first)) score += 40;
    else if (new RegExp(`(^|[^a-z0-9])${first.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`).test(it.t)) score += 25;
    else if (it.t.includes(first)) score += 12;
    score += terms.filter((t) => it.t.includes(t)).length * 6;
    score -= it.t.length / 40;
    out.push({ it, score });
  }
  out.sort((a, b) => b.score - a.score);
  // Keep the groups in the order their best hit ranks, each capped.
  const order: string[] = [];
  const by: Record<string, Indexed[]> = {};
  for (const { it } of out) {
    if (!by[it.group]) {
      by[it.group] = [];
      order.push(it.group);
    }
    if (by[it.group].length < perGroup) by[it.group].push(it);
  }
  return order.flatMap((g) => by[g]);
}

const isTyping = (el: Element | null) =>
  !!el && (/^(input|textarea|select)$/i.test(el.tagName) || (el as HTMLElement).isContentEditable);

/** Opens with / and Ctrl+K (Cmd+K on a Mac) from anywhere, and from the header button. */
export function useSearchHotkeys(open: () => void) {
  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      if ((e.key === "k" || e.key === "K") && (e.ctrlKey || e.metaKey) && !e.altKey) {
        e.preventDefault();
        open();
      } else if (e.key === "/" && !e.ctrlKey && !e.metaKey && !e.altKey && !isTyping(document.activeElement)) {
        e.preventDefault();
        open();
      }
    };
    document.addEventListener("keydown", key);
    return () => document.removeEventListener("keydown", key);
  }, [open]);
}

export function SearchIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.5-3.5" />
    </svg>
  );
}

export function Palette({
  open,
  onClose,
  items,
  quick,
  placeholder,
  empty,
  initial = "",
}: {
  open: boolean;
  onClose: () => void;
  items: () => SearchItem[];
  quick: SearchItem[];
  placeholder: string;
  empty: string;
  initial?: string;
}) {
  const dlg = useRef<HTMLDialogElement>(null);
  const input = useRef<HTMLInputElement>(null);
  const list = useRef<HTMLDivElement>(null);
  const [q, setQ] = useState("");
  const [sel, setSel] = useState(0);
  const nav = useNavigate();
  const uid = useId();
  const index = useMemo<Indexed[]>(
    () => (open ? items().map((it) => ({ ...it, t: norm(it.title), h: norm(`${it.title} ${it.sub ?? ""} ${it.hay ?? ""} ${it.group}`) })) : []),
    // Built once, on first open.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [open && "built"],
  );
  const hits = useMemo(() => (q.trim() ? rank(index, q) : quick.map((it) => ({ ...it, t: "", h: "" }))), [q, index, quick]);

  useEffect(() => {
    const d = dlg.current;
    if (!d) return;
    if (open && !d.open) {
      d.showModal();
      setQ(initial);
      setSel(0);
      requestAnimationFrame(() => input.current?.focus());
    } else if (!open && d.open) d.close();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  useEffect(() => {
    list.current?.querySelector(`[aria-selected="true"]`)?.scrollIntoView({ block: "nearest" });
  }, [sel]);

  const go = (h: SearchItem) => {
    onClose();
    nav(h.to);
  };

  let last = "";
  const optId = (i: number) => `${uid}-o${i}`;
  return (
    <dialog
      ref={dlg}
      className="ui-palette"
      aria-label="Search"
      onClose={onClose}
      onCancel={onClose}
      onClick={(e) => {
        if (e.target === dlg.current) onClose();
      }}
    >
      <div className="in">
        <SearchIcon />
        <input
          ref={input}
          type="text"
          role="combobox"
          aria-expanded="true"
          aria-controls={`${uid}-list`}
          aria-activedescendant={hits[sel] ? optId(sel) : undefined}
          aria-autocomplete="list"
          aria-label="Search"
          autoComplete="off"
          spellCheck={false}
          value={q}
          placeholder={placeholder}
          onChange={(e) => {
            setQ(e.target.value);
            setSel(0);
          }}
          onKeyDown={(e) => {
            if (e.key === "ArrowDown") {
              e.preventDefault();
              setSel((s) => Math.min(s + 1, hits.length - 1));
            } else if (e.key === "ArrowUp") {
              e.preventDefault();
              setSel((s) => Math.max(s - 1, 0));
            } else if (e.key === "Enter" && hits[sel]) {
              e.preventDefault();
              go(hits[sel]);
            }
          }}
        />
        <kbd>Esc</kbd>
      </div>
      <div className="ui-results" id={`${uid}-list`} role="listbox" ref={list} aria-label={q.trim() ? "Results" : "Suggestions"}>
        {q.trim() && hits.length === 0 && (
          <div className="none">
            Nothing matches "{q}". {empty}
          </div>
        )}
        {hits.map((h, i) => {
          const head = h.group !== last ? (last = h.group) : null;
          return (
            <div key={`${h.to}|${h.title}|${i}`} role="presentation">
              {head && (
                <div className="g" role="presentation">
                  {head}
                </div>
              )}
              <a
                id={optId(i)}
                href={h.to}
                role="option"
                aria-selected={i === sel}
                tabIndex={-1}
                onMouseMove={() => setSel(i)}
                onClick={(e) => {
                  e.preventDefault();
                  go(h);
                }}
              >
                <b className={h.mono ? "m" : undefined}>{h.title}</b>
                {h.where && <span className="where">{h.where}</span>}
                {h.sub && <small>{h.sub}</small>}
              </a>
            </div>
          );
        })}
      </div>
      <div className="hint" aria-hidden="true">
        <span>
          <kbd>&uarr;</kbd>
          <kbd>&darr;</kbd> to move
        </span>
        <span>
          <kbd>Enter</kbd> to open
        </span>
        <span>
          <kbd>/</kbd> or <kbd>Ctrl</kbd>
          <kbd>K</kbd> opens search anywhere
        </span>
      </div>
    </dialog>
  );
}
