import { layout } from "./layout.js";

export function welcomePage(name) {
  return layout({ title: "Welcome", body: `<h1>Welcome, ${name}</h1><p>Your account is ready.</p>` });
}
