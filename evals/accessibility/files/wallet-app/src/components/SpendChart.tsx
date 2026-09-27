import { View, StyleSheet } from "react-native";
import { colors } from "../theme";

export type MonthSpend = { month: string; total: number };

// Bar chart of the last months' spending, tallest bar = highest month.
export function SpendChart({ data }: { data: MonthSpend[] }) {
  const max = Math.max(...data.map((d) => d.total));
  return (
    <View style={styles.row}>
      {data.map((d) => (
        <View key={d.month} style={[styles.bar, { height: (d.total / max) * 80 }]} />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "flex-end", gap: 8, height: 80 },
  bar: { width: 24, backgroundColor: colors.accent, borderRadius: 4 },
});
