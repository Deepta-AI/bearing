import { Stack } from "expo-router";
import { SettingsProvider } from "../src/settings/SettingsContext";

export default function Layout() {
  return (
    <SettingsProvider>
      <Stack />
    </SettingsProvider>
  );
}
