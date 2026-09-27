"use client";

import { useActionState } from "react";
import { updateName, type NameState } from "./actions";

const initial: NameState = { status: "idle" };

export function NameForm({ name }: { name: string }) {
  const [state, action, pending] = useActionState(updateName, initial);
  const error = state.status === "error" ? state.fieldErrors?.name?.[0] : undefined;
  return (
    <form action={action}>
      <label htmlFor="name">Name</label>
      <input
        id="name"
        name="name"
        defaultValue={name}
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? "name-error" : undefined}
      />
      {error && <p id="name-error">{error}</p>}
      <button type="submit" disabled={pending}>
        Save
      </button>
      <p role="status" aria-live="polite">
        {state.status !== "idle" ? state.message : ""}
      </p>
    </form>
  );
}
