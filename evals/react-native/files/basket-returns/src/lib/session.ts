import { create } from 'zustand';

import { clearAccessToken, getAccessToken, setAccessToken } from './secure-store';

type SessionState = {
  status: 'loading' | 'signedIn' | 'signedOut';
  restore: () => Promise<void>;
  signIn: (token: string) => Promise<void>;
  signOut: () => Promise<void>;
};

/** Whether someone is signed in. The token itself stays in the secure store. */
export const useSession = create<SessionState>((set) => ({
  status: 'loading',
  restore: async () => {
    const token = await getAccessToken();
    set({ status: token ? 'signedIn' : 'signedOut' });
  },
  signIn: async (token) => {
    await setAccessToken(token);
    set({ status: 'signedIn' });
  },
  signOut: async () => {
    await clearAccessToken();
    set({ status: 'signedOut' });
  },
}));
