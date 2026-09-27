import { apiFetch } from '@/lib/api';

import { createdReturnSchema, type CreatedReturn, type ReturnReason } from './schemas';
import { signUpload } from './signing';

const BUCKET_URL = process.env.EXPO_PUBLIC_UPLOAD_BUCKET_URL ?? '';

/** PUT one photo straight to the returns bucket and return its key. */
export async function uploadPhoto(orderId: string, uri: string): Promise<string> {
  const key = `returns/${orderId}/${Date.now()}.jpg`;
  const expiresAt = Math.floor(Date.now() / 1000) + 600;
  const signature = signUpload(key, expiresAt);
  const file = await fetch(uri);
  const body = await file.blob();
  const res = await fetch(`${BUCKET_URL}/${key}?expires=${expiresAt}&signature=${signature}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'image/jpeg' },
    body,
  });
  if (!res.ok) throw new Error(`upload failed: ${res.status}`);
  return key;
}

type NewReturn = {
  orderId: string;
  lines: { sku: string; qty: number }[];
  reason: ReturnReason;
  photoKeys: string[];
};

/** POST /v1/returns. */
export function createReturn(r: NewReturn): Promise<CreatedReturn> {
  return apiFetch('/v1/returns', createdReturnSchema, {
    method: 'POST',
    body: JSON.stringify({
      order_id: r.orderId,
      lines: r.lines,
      reason: r.reason,
      photo_upload_ids: r.photoKeys,
    }),
  });
}
