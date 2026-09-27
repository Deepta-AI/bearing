import { __reset, completeTask, getOpenTasks, undoComplete } from "../src/store/tasks";

const seed = [
  { id: "a", title: "A", notes: "", done: false },
  { id: "b", title: "B", notes: "", done: false },
];

beforeEach(() => __reset(seed.map((t) => ({ ...t }))));

test("completing a task removes it from the open list", () => {
  completeTask("a");
  expect(getOpenTasks().map((t) => t.id)).toEqual(["b"]);
});

test("undo puts it back", () => {
  completeTask("a");
  undoComplete("a");
  expect(getOpenTasks().map((t) => t.id)).toEqual(["a", "b"]);
});
