import * as ImagePicker from 'expo-image-picker';
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Image, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { ErrorState } from '@/components/ErrorState';
import { useOrder } from '@/features/orders/hooks';
import type { OrderLine } from '@/features/orders/schemas';
import { createReturn, uploadPhoto } from '@/features/returns/api';
import { ReturnReasonPicker } from '@/features/returns/ReturnReasonPicker';
import type { ReturnReason } from '@/features/returns/schemas';
import { errorMessage } from '@/lib/api';

/** Start a return for a delivered order: pick lines, a reason and photos. */
export default function NewReturn() {
  const { orderId } = useLocalSearchParams<{ orderId: string }>();
  const query = useOrder(orderId as string);
  const [lines, setLines] = useState<(OrderLine & { selected: boolean })[]>([]);
  const [reason, setReason] = useState<ReturnReason | null>(null);
  const [photos, setPhotos] = useState<string[]>([]);

  useEffect(() => {
    if (query.data) setLines(query.data.lines.map((l) => ({ ...l, selected: false })));
  }, [query.data]);

  async function addPhoto() {
    const result = await ImagePicker.launchCameraAsync({ mediaTypes: ['images'], quality: 1 });
    if (!result.canceled && result.assets[0]) setPhotos((p) => [...p, result.assets[0].uri]);
  }

  if (query.isPending) return <ActivityIndicator accessibilityLabel="Loading order" />;
  if (query.isError) return <ErrorState message={errorMessage(query.error)} onRetry={() => void query.refetch()} />;

  return (
    <ScrollView contentContainerStyle={styles.screen}>
      <Text style={styles.title}>What went wrong?</Text>
      {lines.map((l, i) => (
        <Pressable
          key={l.sku}
          accessibilityRole="checkbox"
          accessibilityState={{ checked: l.selected }}
          onPress={() => setLines((all) => all.map((x, j) => (j === i ? { ...x, selected: !x.selected } : x)))}
          style={styles.line}
        >
          <Text>
            {l.qty} x {l.name}
          </Text>
        </Pressable>
      ))}
      <ReturnReasonPicker value={reason} onChange={setReason} />
      <View style={styles.photos}>
        {photos.map((uri) => (
          <Image key={uri} source={{ uri }} style={styles.thumb} accessibilityLabel="Photo of the item" />
        ))}
      </View>
      <Pressable accessibilityRole="button" onPress={addPhoto} style={styles.secondary}>
        <Text>Add a photo</Text>
      </Pressable>
      <Pressable
        accessibilityRole="button"
        onPress={async () => {
          const keys = await Promise.all(photos.map((uri) => uploadPhoto(orderId as string, uri)));
          await createReturn({
            orderId: orderId as string,
            lines: lines.filter((l) => l.selected).map((l) => ({ sku: l.sku, qty: l.qty })),
            reason: reason ?? 'damaged',
            photoKeys: keys,
          });
          router.back();
        }}
        style={styles.primary}
      >
        <Text style={styles.primaryText}>Request return</Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { padding: 16, gap: 12 },
  title: { fontSize: 20, fontWeight: '700' },
  line: { minHeight: 44, justifyContent: 'center' },
  photos: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  thumb: { width: 72, height: 72, borderRadius: 6 },
  secondary: { minHeight: 44, borderRadius: 8, borderWidth: 1, borderColor: '#c9ced6', justifyContent: 'center', alignItems: 'center' },
  primary: { minHeight: 44, borderRadius: 8, backgroundColor: '#1f6f43', justifyContent: 'center', alignItems: 'center' },
  primaryText: { color: '#ffffff', fontSize: 16, fontWeight: '600' },
});
