import { Pressable, View, StyleSheet } from "react-native";
import { colors } from "../theme";

// Custom switch that matches the brand look; the native Switch could not be themed on iOS.
export function Toggle({ value, onChange }: { value: boolean; onChange: (v: boolean) => void }) {
  return (
    <Pressable onPress={() => onChange(!value)} style={[styles.track, value && styles.on]}>
      <View style={[styles.thumb, value && styles.thumbOn]} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  track: { width: 44, height: 26, borderRadius: 13, backgroundColor: colors.border, padding: 3 },
  on: { backgroundColor: colors.accent },
  thumb: { width: 20, height: 20, borderRadius: 10, backgroundColor: colors.surface },
  thumbOn: { transform: [{ translateX: 18 }] },
});
