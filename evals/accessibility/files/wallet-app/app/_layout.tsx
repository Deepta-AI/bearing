import { Text, TextInput } from "react-native";
import { Stack } from "expo-router";

// ADR 0004: font scaling is off app-wide so the balance card never clips.
(Text as any).defaultProps = { ...(Text as any).defaultProps, allowFontScaling: false };
(TextInput as any).defaultProps = { ...(TextInput as any).defaultProps, allowFontScaling: false };

export default function RootLayout() {
  return (
    <Stack>
      <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
      <Stack.Screen name="send" options={{ title: "Send money" }} />
      <Stack.Screen name="receipt/[id]" options={{ title: "Receipt" }} />
    </Stack>
  );
}
