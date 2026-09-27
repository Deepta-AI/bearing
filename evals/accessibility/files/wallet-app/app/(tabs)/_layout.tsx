import { Tabs } from "expo-router";
import { Ionicons } from "@expo/vector-icons";

const icon = (name: keyof typeof Ionicons.glyphMap) => ({ color }: { color: string }) => (
  <Ionicons name={name} size={24} color={color} />
);

export default function TabsLayout() {
  return (
    <Tabs screenOptions={{ tabBarShowLabel: false }}>
      <Tabs.Screen name="index" options={{ title: "Home", tabBarIcon: icon("home") }} />
      <Tabs.Screen name="activity" options={{ title: "Activity", tabBarIcon: icon("list") }} />
      <Tabs.Screen name="settings" options={{ title: "Settings", tabBarIcon: icon("settings") }} />
    </Tabs>
  );
}
