import { useSyncExternalStore } from "react";

export type Task = {
  id: string;
  title: string;
  notes: string;
  done: boolean;
};

let tasks: Task[] = [
  { id: "t1", title: "Check fire extinguisher tags", notes: "Ground floor and basement. Photograph any tag older than 12 months.", done: false },
  { id: "t2", title: "Meter reading, block B", notes: "Read both meters in the plant room. The second meter is behind the blue panel; the key is in the site office. If the display is blank, press and hold the lower button for five seconds. Record the reading, the time and the meter serial in the log, and flag anything more than 10 percent above last week's reading to the site lead before you leave.", done: false },
  { id: "t3", title: "Restock first aid kit", notes: "", done: false },
];
const listeners = new Set<() => void>();

function emit() {
  for (const l of listeners) l();
}

export function subscribe(l: () => void) {
  listeners.add(l);
  return () => listeners.delete(l);
}

export function getOpenTasks(): Task[] {
  return tasks.filter((t) => !t.done);
}

let openSnapshot = getOpenTasks();

export function completeTask(id: string) {
  tasks = tasks.map((t) => (t.id === id ? { ...t, done: true } : t));
  openSnapshot = getOpenTasks();
  emit();
}

export function undoComplete(id: string) {
  tasks = tasks.map((t) => (t.id === id ? { ...t, done: false } : t));
  openSnapshot = getOpenTasks();
  emit();
}

export function useOpenTasks(): Task[] {
  return useSyncExternalStore(subscribe, () => openSnapshot);
}

// For tests.
export function __reset(next: Task[]) {
  tasks = next;
  openSnapshot = getOpenTasks();
  emit();
}
