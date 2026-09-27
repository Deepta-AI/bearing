import { Pressable, StyleSheet, Text, View } from 'react-native';

type Props = { message: string; onRetry: () => void };

/** Full-screen error with a retry button. */
export function ErrorState({ message, onRetry }: Props) {
  return (
    <View style={styles.box}>
      <Text style={styles.text}>{message}</Text>
      <Pressable accessibilityRole="button" onPress={onRetry} style={styles.button}>
        <Text style={styles.buttonText}>Try again</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  box: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24, gap: 16 },
  text: { fontSize: 16, textAlign: 'center' },
  button: { minHeight: 44, paddingHorizontal: 20, justifyContent: 'center', borderRadius: 8, backgroundColor: '#1f6f43' },
  buttonText: { color: '#ffffff', fontSize: 16, fontWeight: '600' },
});
