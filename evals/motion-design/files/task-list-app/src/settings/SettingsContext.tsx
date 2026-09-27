import AsyncStorage from "@react-native-async-storage/async-storage";
import { createContext, ReactNode, useContext, useEffect, useState } from "react";

// In-app preferences. "Reduce animations" was added in 2.2 for crews who
// use the app in moving vehicles; it is separate from the OS setting.
export type Settings = {
  reduceAnimations: boolean;
  setReduceAnimations: (v: boolean) => void;
};

const KEY = "settings.reduceAnimations";
const SettingsContext = createContext<Settings>({
  reduceAnimations: false,
  setReduceAnimations: () => {},
});

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [reduceAnimations, setState] = useState(false);

  useEffect(() => {
    AsyncStorage.getItem(KEY).then((v) => setState(v === "1"));
  }, []);

  const setReduceAnimations = (v: boolean) => {
    setState(v);
    AsyncStorage.setItem(KEY, v ? "1" : "0");
  };

  return (
    <SettingsContext.Provider value={{ reduceAnimations, setReduceAnimations }}>
      {children}
    </SettingsContext.Provider>
  );
}

export function useSettings() {
  return useContext(SettingsContext);
}
