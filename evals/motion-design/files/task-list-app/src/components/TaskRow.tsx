import { useRef, useState } from "react";
import { Animated, Pressable, StyleSheet, Text, View } from "react-native";
import { colors, space } from "../theme";
import type { Task } from "../store/tasks";

type Props = {
  task: Task;
  onComplete: (id: string) => void;
};

export function TaskRow({ task, onComplete }: Props) {
  const [open, setOpen] = useState(false);
  const height = useRef(new Animated.Value(0)).current;

  const toggleDetails = () => {
    Animated.timing(height, {
      toValue: open ? 0 : 120,
      duration: 300,
      useNativeDriver: false,
    }).start();
    setOpen(!open);
  };

  return (
    <View style={styles.row}>
      <View style={styles.header}>
        <Pressable
          accessibilityRole="checkbox"
          accessibilityState={{ checked: task.done }}
          accessibilityLabel={`Complete ${task.title}`}
          onPress={() => onComplete(task.id)}
          style={styles.box}
          hitSlop={8}
        />
        <Pressable
          style={styles.titleArea}
          onPress={toggleDetails}
          accessibilityRole="button"
          accessibilityState={{ expanded: open }}
          accessibilityHint="Shows the notes for this task"
        >
          <Text style={styles.title}>{task.title}</Text>
        </Pressable>
      </View>
      <Animated.View style={[styles.details, { height }]}>
        <Text style={styles.notes}>{task.notes || "No notes."}</Text>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    backgroundColor: colors.surface,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.border,
    paddingHorizontal: space[4],
  },
  header: { flexDirection: "row", alignItems: "center", paddingVertical: space[3] },
  box: {
    width: 24,
    height: 24,
    borderRadius: 6,
    borderWidth: 2,
    borderColor: colors.accent,
    marginRight: space[3],
  },
  titleArea: { flex: 1 },
  title: { fontSize: 16, color: colors.text },
  details: { overflow: "hidden" },
  notes: { color: colors.muted, paddingBottom: space[3] },
});
