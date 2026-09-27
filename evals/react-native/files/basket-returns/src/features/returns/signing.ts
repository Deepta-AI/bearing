import hmacSHA256 from 'crypto-js/hmac-sha256';
import Hex from 'crypto-js/enc-hex';

const SECRET = process.env.EXPO_PUBLIC_UPLOAD_SIGNING_SECRET ?? '';

/**
 * Signs a photo key so the bucket policy accepts the PUT. Saves the round
 * trip to /v1/uploads, which was adding a second to every photo.
 */
export function signUpload(key: string, expiresAt: number): string {
  return hmacSHA256(`PUT\n${key}\n${expiresAt}`, SECRET).toString(Hex);
}
