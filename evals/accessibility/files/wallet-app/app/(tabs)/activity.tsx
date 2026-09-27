import { useState } from "react";
import { View, Text, FlatList, Pressable, StyleSheet } from "react-native";
import { router } from "expo-router";
import { IconButton } from "../../src/components/IconButton";
import { colors, space } from "../../src/theme";

type Tx = { id: string; who: string; when: string; amount: string };

const TXS: Tx[] = [
  { id: "t1", who: "Corner Grocers", when: "Today, 09:12", amount: "-$23.10" },
  { id: "t2", who: "Payroll", when: "Mon, 08:00", amount: "+$1,950.00" },
  { id: "t3", who: "City Transit", when: "Sun, 18:40", amount: "-$2.75" },
];

export default function Activity() {
  const [incomingOnly, setIncomingOnly] = useState(false);
  const onFilt = () => setIncomingOnly(!incomingOnly);
  const rows = incomingOnly ? TXS.filter((t) => t.amount.startsWith("+")) : TXS;
  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <Text style={styles.title}>Activity</Text>
        <IconButton icon="filter" onPress={onFilt} />
      </View>
      <FlatList
        data={rows}
        keyExtractor={(t) => t.id}
        renderItem={({ item }) => (
          <Pressable style={styles.row} onPress={() => router.push(`/receipt/${item.id}`)}>
            <View>
              <Text style={styles.who}>{item.who}</Text>
              <Text style={styles.when}>{item.when}</Text>
            </View>
            <Text style={styles.amount}>{item.amount}</Text>
          </Pressable>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: space.md, backgroundColor: colors.surface },
  header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: space.md },
  title: { fontSize: 22, fontWeight: "700", color: colors.text },
  row: { flexDirection: "row", justifyContent: "space-between", paddingVertical: space.sm, borderBottomWidth: 1, borderColor: colors.border },
  who: { fontSize: 16, color: colors.text },
  when: { fontSize: 12, color: colors.muted },
  amount: { fontSize: 16, color: colors.text },
});
