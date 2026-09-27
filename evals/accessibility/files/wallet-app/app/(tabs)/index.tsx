import { useState } from "react";
import { View, Text, Image, Pressable, StyleSheet } from "react-native";
import { router } from "expo-router";
import { IconButton } from "../../src/components/IconButton";
import { SpendChart } from "../../src/components/SpendChart";
import { colors, space } from "../../src/theme";

const SPEND = [
  { month: "Jun", total: 1240 },
  { month: "Jul", total: 980 },
  { month: "Aug", total: 1410 },
  { month: "Sep", total: 860 },
];

export default function Home() {
  const [hidden, setHidden] = useState(false);
  return (
    <View style={styles.screen}>
      <Image source={require("../../assets/wordmark.png")} style={styles.logo} accessibilityLabel="logo" />
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Text style={styles.label}>Available balance</Text>
          <IconButton icon={hidden ? "eye-off" : "eye"} onPress={() => setHidden(!hidden)} />
        </View>
        <Text style={styles.balance}>{hidden ? "••••••" : "$2,318.40"}</Text>
        <Text style={styles.label}>Updated 2 minutes ago</Text>
      </View>
      <Text style={styles.section}>Spending, last 4 months</Text>
      <SpendChart data={SPEND} />
      <Pressable style={styles.send} onPress={() => router.push("/send")}>
        <Text style={styles.sendText}>Send money</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: space.md, backgroundColor: colors.surface },
  logo: { width: 120, height: 24, marginBottom: space.md },
  card: { height: 120, padding: space.md, borderRadius: 12, borderWidth: 1, borderColor: colors.border },
  cardHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  label: { fontSize: 13, color: colors.muted },
  balance: { fontSize: 32, fontWeight: "700", color: colors.text },
  section: { marginTop: space.lg, marginBottom: space.sm, fontWeight: "600", color: colors.text },
  send: { marginTop: space.lg, padding: space.md, borderRadius: 8, backgroundColor: colors.accent },
  sendText: { color: colors.surface, textAlign: "center", fontWeight: "600" },
});
