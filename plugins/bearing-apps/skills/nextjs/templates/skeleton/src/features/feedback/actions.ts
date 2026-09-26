"use server";

import { z } from "zod";

import { requireSession } from "@/lib/auth";

import { feedbackSchema, type FeedbackState } from "./schema";

/**
 * submitFeedback is a server action: a public POST endpoint whatever form
 * calls it. The order is fixed: authorise, validate, act, return a state
 * the form can render. Never return the raw error, never trust FormData.
 */
export async function submitFeedback(
  _previous: FeedbackState,
  formData: FormData,
): Promise<FeedbackState> {
  await requireSession();

  const parsed = feedbackSchema.safeParse({ message: formData.get("message") });
  if (!parsed.success) {
    return { status: "error", fieldErrors: z.flattenError(parsed.error).fieldErrors };
  }

  // Do the work through the API (apiFetch with method POST), never with a
  // database client inside the action, then updateTag("<tag>") for every
  // cached read the write changed. The template records nothing yet.
  return { status: "ok" };
}
