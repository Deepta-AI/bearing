import { Pressable, StyleSheet, Text, View } from "react-native";
import { colors, space } from "../theme";

type Props = { title: string; onUndo: () => void };

export function UndoBar({ title, onUndo }: Props) {
  return (
    <View style={styles.bar}>
      <Text style={styles.text} numberOfLines={1}>
        Done: {title}
      </Text>
      <Pressable onPress={onUndo} accessibilityRole="button" hitSlop={8}>
        <Text style={styles.action}>Undo</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  bar: {
    position: "absolute",
    left: space[4],
    right: space[4],
    bottom: space[6],
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    backgroundColor: colors.text,
    borderRadius: 8,
    padding: space[3],
  },
  text: { color: colors.surface, flex: 1, marginRight: space[3] },
  action: { color: colors.accent, fontWeight: "600" },
});
