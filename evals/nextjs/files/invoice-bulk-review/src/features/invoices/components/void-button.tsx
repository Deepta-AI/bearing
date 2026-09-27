"use client";

import { useActionState } from "react";
import { voidInvoice, type ActionState } from "@/features/invoices/actions";

const idle: ActionState = { status: "idle" };

export function VoidButton({ id, number }: { id: string; number: string }) {
  const [state, action, pending] = useActionState(voidInvoice, idle);
  return (
    <form action={action}>
      <input type="hidden" name="id" value={id} />
      <button type="submit" disabled={pending} aria-label={`Void invoice ${number}`}>
        Void
      </button>
      <span role="status">{state.status === "error" ? state.message : ""}</span>
    </form>
  );
}
