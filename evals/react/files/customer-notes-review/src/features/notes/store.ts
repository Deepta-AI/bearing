import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Note } from "./schemas";

type NotesState = {
  notes: Note[];
  setNotes: (notes: Note[]) => void;
  addNote: (note: Note) => void;
  removeNote: (id: string) => void;
};

// Keeps the notes around so the panel does not flash empty on reload.
export const useNotesStore = create<NotesState>()(
  persist(
    (set) => ({
      notes: [],
      setNotes: (notes) => set({ notes }),
      addNote: (note) => set((s) => ({ notes: [note, ...s.notes] })),
      removeNote: (id) => set((s) => ({ notes: s.notes.filter((n) => n.id !== id) })),
    }),
    { name: "support-console-notes" },
  ),
);
