import { StyleSheet, Text, View } from 'react-native';

type Props = { title: string; hint?: string };

/** Full-screen message for a list with nothing in it. */
export function EmptyState({ title, hint }: Props) {
  return (
    <View style={styles.box}>
      <Text style={styles.title}>{title}</Text>
      {hint ? <Text style={styles.hint}>{hint}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  box: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24, gap: 8 },
  title: { fontSize: 18, fontWeight: '600' },
  hint: { fontSize: 15, color: '#5b6470', textAlign: 'center' },
});
