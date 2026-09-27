import { useState } from "react";
import { View, Text, TextInput, Pressable, StyleSheet } from "react-native";
import { colors, space } from "../src/theme";

export default function Send() {
  const [to, setTo] = useState("");
  const [amount, setAmount] = useState("");
  const [error, setError] = useState("");
  const [sent, setSent] = useState(false);

  const submit = () => {
    const value = Number(amount);
    if (!to.trim()) return setError("Enter who you are paying");
    if (!Number.isFinite(value) || value <= 0) return setError("Enter an amount above zero");
    setError("");
    setSent(true);
  };

  return (
    <View style={styles.screen}>
      <TextInput style={styles.input} placeholder="Name, phone or email" value={to} onChangeText={setTo} />
      <TextInput style={styles.input} placeholder="$0.00" keyboardType="decimal-pad" value={amount} onChangeText={setAmount} />
      {error ? <Text style={styles.error}>{error}</Text> : null}
      <Pressable style={styles.button} onPress={submit}>
        <Text style={styles.buttonText}>Send</Text>
      </Pressable>
      {sent ? <Text style={styles.success}>Payment sent</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: space.md, backgroundColor: colors.surface },
  input: { borderWidth: 1, borderColor: colors.border, borderRadius: 8, padding: space.sm, marginBottom: space.sm, fontSize: 16 },
  error: { color: colors.error, fontSize: 14, marginBottom: space.sm },
  button: { padding: space.md, borderRadius: 8, backgroundColor: colors.accent },
  buttonText: { color: colors.surface, textAlign: "center", fontWeight: "600" },
  success: { marginTop: space.md, color: colors.success, fontSize: 14 },
});
