import * as SecureStore from 'expo-secure-store';

/** Every secret the app stores. Values must stay under 2 KB. */
export type SecretKey = 'accessToken' | 'refreshToken';

/** Read a secret, or null when none is stored. */
export function getToken(key: SecretKey): Promise<string | null> {
  return SecureStore.getItemAsync(key);
}

/** Store a secret in the keychain (iOS) or keystore-backed storage (Android). */
export function setToken(key: SecretKey, value: string): Promise<void> {
  return SecureStore.setItemAsync(key, value, {
    keychainAccessible: SecureStore.AFTER_FIRST_UNLOCK,
  });
}

/** Remove a secret. Call for every key on logout. */
export function deleteToken(key: SecretKey): Promise<void> {
  return SecureStore.deleteItemAsync(key);
}
