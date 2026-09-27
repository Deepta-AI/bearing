import { Link } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { useSession } from '@/lib/session';

/** Account tab: links to the customer's own records, and sign out. */
export default function Account() {
  const signOut = useSession((s) => s.signOut);

  return (
    <View style={styles.screen}>
      <Link href="/addresses" asChild>
        <Pressable accessibilityRole="link" style={styles.row}>
          <Text style={styles.rowText}>Saved addresses</Text>
        </Pressable>
      </Link>
      <Pressable accessibilityRole="button" onPress={() => void signOut()} style={styles.row}>
        <Text style={styles.rowText}>Sign out</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, paddingVertical: 8 },
  row: { minHeight: 52, paddingHorizontal: 20, justifyContent: 'center', borderBottomWidth: 1, borderBottomColor: '#e3e6ea' },
  rowText: { fontSize: 16 },
});
