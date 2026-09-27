import { z } from "zod";

export const NoteSchema = z.object({
  id: z.string(),
  customerId: z.string(),
  body: z.string(),
  authorName: z.string(),
  createdAt: z.iso.datetime(),
});

export const NoteListSchema = z.array(NoteSchema);

export interface Note {
  id: string;
  customerId: string;
  body: string;
  authorName: string;
  createdAt: string;
}
