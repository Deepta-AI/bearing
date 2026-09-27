import * as SecureStore from 'expo-secure-store';

const ACCESS_TOKEN = 'accessToken';

/** The stored access token, or null when signed out. */
export function getAccessToken(): Promise<string | null> {
  return SecureStore.getItemAsync(ACCESS_TOKEN);
}

/** Store the access token in the keychain (iOS) or keystore (Android). */
export function setAccessToken(token: string): Promise<void> {
  return SecureStore.setItemAsync(ACCESS_TOKEN, token);
}

/** Remove the access token on sign out. */
export function clearAccessToken(): Promise<void> {
  return SecureStore.deleteItemAsync(ACCESS_TOKEN);
}
