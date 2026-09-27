import { StyleSheet, Switch, Text, View } from "react-native";
import { Stack } from "expo-router";
import { useSettings } from "../src/settings/SettingsContext";
import { colors, space } from "../src/theme";

export default function SettingsScreen() {
  const { reduceAnimations, setReduceAnimations } = useSettings();
  return (
    <View style={styles.screen}>
      <Stack.Screen options={{ title: "Settings" }} />
      <View style={styles.row}>
        <Text style={styles.label}>Reduce animations</Text>
        <Switch value={reduceAnimations} onValueChange={setReduceAnimations} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.bg, padding: space[4] },
  row: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  label: { fontSize: 16, color: colors.text },
});
