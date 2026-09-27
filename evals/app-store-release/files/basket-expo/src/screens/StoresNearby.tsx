import * as Location from 'expo-location';
import { useEffect, useState } from 'react';
import { FlatList, Text } from 'react-native';
import { getJson } from '../lib/api';
import { useSession } from '../lib/session';

type Store = { id: string; name: string; distanceM: number };

export default function StoresNearby() {
  const { token } = useSession();
  const [stores, setStores] = useState<Store[]>([]);

  useEffect(() => {
    (async () => {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') return;
      const pos = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.High });
      const { latitude, longitude } = pos.coords;
      // The server stores the last search position on the account for "stores you visit".
      setStores(await getJson<Store[]>(`/v1/stores/nearby?lat=${latitude}&lng=${longitude}`, token));
    })();
  }, [token]);

  return <FlatList data={stores} renderItem={({ item }) => <Text>{item.name}</Text>} />;
}
