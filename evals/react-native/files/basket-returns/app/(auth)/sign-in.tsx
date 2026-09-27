import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, TextInput } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { z } from 'zod';

import { apiFetch, errorMessage } from '@/lib/api';
import { useSession } from '@/lib/session';

const tokenSchema = z.object({ access_token: z.string() });

/** Phone and one-time code sign in. */
export default function SignIn() {
  const signIn = useSession((s) => s.signIn);
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    try {
      const { access_token } = await apiFetch('/v1/sessions', tokenSchema, {
        method: 'POST',
        body: JSON.stringify({ phone, code }),
      });
      await signIn(access_token);
      router.replace('/');
    } catch (e) {
      setError(errorMessage(e));
    }
  }

  return (
    <SafeAreaView style={styles.screen}>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.form}>
        <Text style={styles.title}>Sign in to Basket</Text>
        <TextInput accessibilityLabel="Phone number" keyboardType="phone-pad" value={phone} onChangeText={setPhone} style={styles.input} />
        <TextInput accessibilityLabel="One-time code" keyboardType="number-pad" value={code} onChangeText={setCode} style={styles.input} />
        {error ? <Text style={styles.error}>{error}</Text> : null}
        <Pressable accessibilityRole="button" onPress={() => void submit()} style={styles.button}>
          <Text style={styles.buttonText}>Sign in</Text>
        </Pressable>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  form: { flex: 1, padding: 24, gap: 12, justifyContent: 'center' },
  title: { fontSize: 24, fontWeight: '700' },
  input: { minHeight: 44, borderWidth: 1, borderColor: '#c9ced6', borderRadius: 8, paddingHorizontal: 12 },
  error: { color: '#b3261e' },
  button: { minHeight: 44, borderRadius: 8, backgroundColor: '#1f6f43', justifyContent: 'center', alignItems: 'center' },
  buttonText: { color: '#ffffff', fontSize: 16, fontWeight: '600' },
});
