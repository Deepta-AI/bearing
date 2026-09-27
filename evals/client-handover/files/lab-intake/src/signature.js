import { createHmac, timingSafeEqual } from 'node:crypto';

// Verifies the hex HMAC-SHA256 a partner lab sends in X-Lab-Signature.
export function verifySignature(secret, rawBody, signature) {
  const want = createHmac('sha256', secret).update(rawBody).digest();
  const got = Buffer.from(String(signature), 'hex');
  return got.length === want.length && timingSafeEqual(got, want);
}
