import * as SecureStore from 'expo-secure-store';
import { useEffect, useState } from 'react';

export async function getToken(): Promise<string> {
  return (await SecureStore.getItemAsync('session_token')) ?? '';
}

export function useSession() {
  const [token, setToken] = useState('');
  useEffect(() => {
    getToken().then(setToken);
  }, []);
  return { token };
}
