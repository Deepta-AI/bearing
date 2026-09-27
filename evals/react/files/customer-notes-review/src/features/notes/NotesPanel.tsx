import { useEffect, useRef, useState } from "react";
import { summarizeNotes } from "./api";
import { useAddNote, useDeleteNote, useNotes } from "./hooks";
import { SparkIcon, TrashIcon } from "./icons";
import { useNotesStore } from "./store";

export function NotesPanel({ customerId }: { customerId: string }) {
  const { data } = useNotes(customerId);
  const notes = useNotesStore((s) => s.notes);
  const setNotes = useNotesStore((s) => s.setNotes);
  const addNote = useAddNote(customerId);
  const deleteNote = useDeleteNote(customerId);
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState("");
  const [summary, setSummary] = useState<string | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (data) setNotes(data);
  }, [data, setNotes]);

  // Put the cursor in the box when the form opens.
  useEffect(() => {
    if (open) textareaRef.current?.focus();
  }, [open]);

  async function summarise() {
    setSummary(await summarizeNotes(notes));
  }

  return (
    <section aria-labelledby="notes-heading" className="mt-8">
      <div className="flex items-center gap-2">
        <h2 id="notes-heading" className="text-lg font-semibold">
          Notes
        </h2>
        <button type="button" onClick={summarise} className="ml-auto rounded-md p-1">
          <SparkIcon />
        </button>
        <button type="button" onClick={() => setOpen(true)} className="rounded-md border border-border px-2 py-1">
          Add note
        </button>
      </div>

      {summary && <p className="mt-2 text-sm text-[#555]">{summary}</p>}

      {open && (
        <form
          className="mt-2 flex flex-col gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            addNote.mutate(draft, {
              onSuccess: () => {
                setDraft("");
                setOpen(false);
              },
            });
          }}
        >
          <textarea
            ref={textareaRef}
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder="Write a note"
            className="rounded-md border border-border p-2"
          />
          <button type="submit" className="self-start rounded-md bg-primary px-3 py-1 text-white">
            Save
          </button>
        </form>
      )}

      {notes.length === 0 ? (
        <p className="mt-2 text-muted-foreground">No notes yet.</p>
      ) : (
        <ul className="mt-2">
          {notes.map((n, i) => (
            <li key={i} className="border-t border-border py-2">
              <div dangerouslySetInnerHTML={{ __html: n.body.replace(/\n/g, "<br>") }} />
              <p className="text-xs text-muted-foreground">
                {n.authorName}, {new Date(n.createdAt).toLocaleString("en-IN")}
              </p>
              <span className="cursor-pointer text-destructive" onClick={() => deleteNote.mutate(n.id)}>
                <TrashIcon />
              </span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
