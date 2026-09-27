// Generated from docs/design/tokens.json by the design system. Edit the
// tokens, not this file.
import { Easing } from "react-native";

export const colors = {
  bg: "#F7F8FA",
  surface: "#FFFFFF",
  text: "#1D2330",
  muted: "#6B7385",
  accent: "#1F8A5B",
  border: "#E3E6EC",
};

export const space = { 2: 8, 3: 12, 4: 16, 6: 24 } as const;

export const motion = {
  duration: {
    instant: 80,
    fast: 150,
    base: 240,
    slow: 400,
  },
  easing: {
    standard: Easing.bezier(0.2, 0, 0, 1),
    enter: Easing.bezier(0, 0, 0.2, 1),
    exit: Easing.bezier(0.4, 0, 1, 1),
  },
} as const;
