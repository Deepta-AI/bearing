import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { createNote, deleteNote, fetchNotes } from "./api";
import { useNotesStore } from "./store";

export function useNotes(customerId: string) {
  return useQuery({
    queryKey: ["notes"],
    queryFn: () => fetchNotes(customerId),
  });
}

export function useAddNote(customerId: string) {
  const qc = useQueryClient();
  const addNote = useNotesStore((s) => s.addNote);
  return useMutation({
    mutationFn: (body: string) => createNote(customerId, body),
    onSuccess: (note) => {
      addNote(note);
      qc.invalidateQueries({ queryKey: ["customer-notes", customerId] });
    },
  });
}

export function useDeleteNote(customerId: string) {
  const removeNote = useNotesStore((s) => s.removeNote);
  return useMutation({
    mutationFn: (noteId: string) => deleteNote(customerId, noteId),
    onSuccess: (_, noteId) => removeNote(noteId),
  });
}
