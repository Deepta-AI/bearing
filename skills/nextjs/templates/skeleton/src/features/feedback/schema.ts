import { z } from "zod";

// The form's contract. The server action parses FormData against it; the
// client never trusts its own inputs.
export const feedbackSchema = z.object({
  message: z
    .string()
    .trim()
    .min(3, "Write at least 3 characters")
    .max(500, "Keep it under 500 characters"),
});

export type Feedback = z.infer<typeof feedbackSchema>;

/** FeedbackState is what useActionState holds between submissions. */
export type FeedbackState =
  | { status: "idle" }
  | { status: "ok" }
  | { status: "error"; fieldErrors: Partial<Record<keyof Feedback, string[]>>; formError?: string };
