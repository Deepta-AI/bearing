"use client";

import { useActionState, useState } from "react";
import { bulkMarkPaid, type ActionState } from "@/features/invoices/actions";
import { publicEnv } from "@/env";

const idle: ActionState = { status: "idle" };

export function BulkToolbar({
  orgId,
  ids,
  removeAction,
}: {
  orgId: string;
  ids: string[];
  removeAction: (prev: ActionState, formData: FormData) => Promise<ActionState>;
}) {
  const [selected, setSelected] = useState<string[]>([]);
  const [paidState, markPaid, paying] = useActionState(bulkMarkPaid, idle);
  const [removeState, remove, removing] = useActionState(removeAction, idle);

  async function exportCsv() {
    const res = await fetch(`${publicEnv.NEXT_PUBLIC_LEDGER_API_URL}/invoices/export.csv`, {
      headers: {
        Authorization: `Bearer ${publicEnv.NEXT_PUBLIC_LEDGER_API_KEY}`,
        "X-Org-Id": orgId,
      },
    });
    const url = URL.createObjectURL(await res.blob());
    window.location.assign(url);
  }

  return (
    <div>
      <fieldset>
        <legend>Select invoices</legend>
        {ids.map((id) => (
          <label key={id}>
            <input
              type="checkbox"
              checked={selected.includes(id)}
              onChange={(e) =>
                setSelected((s) => (e.target.checked ? [...s, id] : s.filter((x) => x !== id)))
              }
            />
            {id}
          </label>
        ))}
      </fieldset>
      <form action={markPaid}>
        {selected.map((id) => (
          <input key={id} type="hidden" name="ids" value={id} />
        ))}
        <button type="submit" disabled={paying || selected.length === 0}>
          Mark paid
        </button>
      </form>
      <form action={remove}>
        {selected.map((id) => (
          <input key={id} type="hidden" name="ids" value={id} />
        ))}
        <button type="submit" disabled={removing || selected.length === 0}>
          Remove
        </button>
      </form>
      <button type="button" onClick={exportCsv}>
        Export CSV
      </button>
      <p role="status" aria-live="polite">
        {paidState.status === "error" ? paidState.message : ""}
        {removeState.status === "error" ? removeState.message : ""}
      </p>
    </div>
  );
}
