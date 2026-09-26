"use client";

import { useActionState } from "react";

import { Button } from "@/components/ui/button";

import { submitFeedback } from "../actions";
import { type FeedbackState } from "../schema";

const initialState: FeedbackState = { status: "idle" };

interface FeedbackFormProps {
  /** The server action; tests pass a fake. */
  action?: typeof submitFeedback;
}

/**
 * FeedbackForm is a client component only because it needs useActionState
 * for pending and error state. Validation lives in the action; the HTML
 * attributes here are a convenience, not the rule.
 */
export function FeedbackForm({ action = submitFeedback }: FeedbackFormProps) {
  const [state, formAction, pending] = useActionState(action, initialState);
  const messageError = state.status === "error" ? state.fieldErrors.message?.[0] : undefined;

  return (
    <form action={formAction} className="space-y-3" aria-labelledby="feedback-heading">
      <h2 id="feedback-heading" className="text-lg font-semibold">
        Feedback
      </h2>
      <div className="space-y-1">
        <label htmlFor="message" className="text-sm font-medium">
          Message
        </label>
        <textarea
          id="message"
          name="message"
          rows={3}
          aria-invalid={messageError !== undefined}
          aria-describedby={messageError !== undefined ? "message-error" : undefined}
          className="w-full rounded-md border bg-background px-3 py-2 text-sm focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none aria-invalid:border-destructive"
        />
        {messageError !== undefined && (
          <p id="message-error" className="text-sm text-destructive">
            {messageError}
          </p>
        )}
      </div>
      <Button type="submit" disabled={pending}>
        {pending ? "Sending" : "Send"}
      </Button>
      <p role="status" aria-live="polite" className="text-sm text-muted-foreground">
        {state.status === "ok" ? "Thanks, received." : null}
      </p>
    </form>
  );
}
