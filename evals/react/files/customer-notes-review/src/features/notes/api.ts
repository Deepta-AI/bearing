import { apiFetch } from "@/lib/api";
import { NoteListSchema, NoteSchema, type Note } from "./schemas";

export function fetchNotes(customerId: string) {
  return apiFetch(`/api/customers/${customerId}/notes`, NoteListSchema);
}

export function createNote(customerId: string, body: string) {
  return apiFetch(`/api/customers/${customerId}/notes`, NoteSchema, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ body }),
  });
}

export async function deleteNote(customerId: string, noteId: string) {
  await fetch(new URL(`/api/customers/${customerId}/notes/${noteId}`, import.meta.env.VITE_API_BASE_URL), {
    method: "DELETE",
  });
}

// Summarises the notes with the summarisation provider.
export async function summarizeNotes(notes: Note[]) {
  const res = await fetch(import.meta.env.VITE_SUMMARY_API_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${import.meta.env.VITE_SUMMARY_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ text: notes.map((n) => n.body).join("\n\n") }),
  });
  const json = await res.json();
  return json.summary as string;
}
