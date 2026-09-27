import { create } from "zustand";
import { persist } from "zustand/middleware";

type UiState = {
  density: "comfortable" | "compact";
  setDensity: (d: UiState["density"]) => void;
};

// UI preferences only (ADR-0002): nothing here names a customer.
export const useUiStore = create<UiState>()(
  persist(
    (set) => ({
      density: "comfortable",
      setDensity: (density) => set({ density }),
    }),
    { name: "support-console-ui" },
  ),
);
