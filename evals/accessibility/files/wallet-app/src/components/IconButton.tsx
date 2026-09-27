import { Pressable, StyleSheet } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { colors } from "../theme";

type Props = {
  icon: keyof typeof Ionicons.glyphMap;
  onPress: () => void;
  size?: number;
};

// Used on Home (balance visibility), Activity (filter) and Receipt (share).
export function IconButton({ icon, onPress, size = 20 }: Props) {
  return (
    <Pressable onPress={onPress} style={styles.button}>
      <Ionicons name={icon} size={size} color={colors.text} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: { width: 28, height: 28, alignItems: "center", justifyContent: "center" },
});
