"use server";

import { revalidateTag } from "next/cache";
import { ApiError, customerTag, updateCustomerName } from "@/lib/api";
import { UpdateNameSchema } from "@/lib/schemas";
import { requireSession } from "@/lib/session";

export type NameState =
  | { status: "idle" }
  | { status: "ok"; message: string }
  | { status: "error"; message: string; fieldErrors?: Record<string, string[] | undefined> };

export async function updateName(_prev: NameState, formData: FormData): Promise<NameState> {
  const session = await requireSession();
  const parsed = UpdateNameSchema.safeParse({ name: formData.get("name") });
  if (!parsed.success) {
    return {
      status: "error",
      message: "Check the highlighted field.",
      fieldErrors: parsed.error.flatten().fieldErrors,
    };
  }
  try {
    await updateCustomerName(session.customerId, parsed.data.name);
  } catch (e) {
    if (e instanceof ApiError && e.status === 422) {
      return { status: "error", message: "The name was not accepted." };
    }
    return { status: "error", message: "Could not save your name. Try again." };
  }
  revalidateTag(customerTag(session.customerId));
  return { status: "ok", message: "Name saved." };
}
