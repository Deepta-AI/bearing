import { useEffect, useRef, useState } from "react";
import { FlatList, StyleSheet, View } from "react-native";
import { Stack } from "expo-router";
import { TaskRow } from "../src/components/TaskRow";
import { UndoBar } from "../src/components/UndoBar";
import { completeTask, undoComplete, useOpenTasks, type Task } from "../src/store/tasks";
import { colors } from "../src/theme";

const UNDO_MS = 4000;

export default function Today() {
  const tasks = useOpenTasks();
  const [lastDone, setLastDone] = useState<Task | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout>>();

  useEffect(() => () => clearTimeout(timer.current), []);

  const onComplete = (id: string) => {
    const task = tasks.find((t) => t.id === id) ?? null;
    completeTask(id);
    setLastDone(task);
    clearTimeout(timer.current);
    timer.current = setTimeout(() => setLastDone(null), UNDO_MS);
  };

  const onUndo = () => {
    if (lastDone) undoComplete(lastDone.id);
    setLastDone(null);
  };

  return (
    <View style={styles.screen}>
      <Stack.Screen options={{ title: "Today" }} />
      <FlatList
        data={tasks}
        keyExtractor={(t) => t.id}
        renderItem={({ item }) => <TaskRow task={item} onComplete={onComplete} />}
      />
      {lastDone && <UndoBar title={lastDone.title} onUndo={onUndo} />}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.bg },
});
