import { useEffect, useState } from 'react';
import { getJson } from './api';
import { getToken } from './session';

export type Account = { id: string; email: string };

export function useAccount(): Account | null {
  const [account, setAccount] = useState<Account | null>(null);
  useEffect(() => {
    getToken().then((t) => (t ? getJson<Account>('/v1/me', t).then(setAccount) : null));
  }, []);
  return account;
}
