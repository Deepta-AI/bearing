import { View, Text, Share, StyleSheet } from "react-native";
import { useLocalSearchParams } from "expo-router";
import { IconButton } from "../../src/components/IconButton";
import { colors, space } from "../../src/theme";

export default function Receipt() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const share = () => Share.share({ message: `Pocketline receipt ${id}` });
  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <Text style={styles.title}>Receipt {id}</Text>
        <IconButton icon="share-outline" onPress={share} />
      </View>
      <Text style={styles.line}>Status: completed</Text>
      <Text style={styles.small}>Keep this receipt for your records.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: space.md, backgroundColor: colors.surface },
  header: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  title: { fontSize: 20, fontWeight: "700", color: colors.text },
  line: { marginTop: space.md, fontSize: 16, color: colors.text },
  small: { marginTop: space.sm, fontSize: 12, color: colors.muted },
});
