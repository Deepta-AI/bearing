import { useState } from "react";
import { View, Text, Switch, StyleSheet } from "react-native";
import { Toggle } from "../../src/components/Toggle";
import { colors, space } from "../../src/theme";

export default function Settings() {
  const [biometric, setBiometric] = useState(true);
  const [notify, setNotify] = useState(false);
  return (
    <View style={styles.screen}>
      <View style={styles.row}>
        <Text style={styles.label}>Sign in with Face ID or fingerprint</Text>
        <Toggle value={biometric} onChange={setBiometric} />
      </View>
      <View style={styles.row}>
        <Text style={styles.label}>Payment notifications</Text>
        <Switch value={notify} onValueChange={setNotify} />
      </View>
      <Text style={styles.footnote}>Version 1.8.0</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: space.md, backgroundColor: colors.surface },
  row: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingVertical: space.md },
  label: { fontSize: 16, color: colors.text, flexShrink: 1 },
  footnote: { marginTop: space.lg, fontSize: 12, color: colors.muted },
});
