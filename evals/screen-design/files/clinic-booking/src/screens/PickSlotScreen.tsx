import { useEffect, useState } from "react";
import { ActivityIndicator, FlatList, Pressable, Text, View } from "react-native";
import { getSlots } from "../api/booking.js";

// First pass; follows docs/design/screens/booking/S-01-pick-slot.html once approved.
export function PickSlotScreen({ clinicId, date, onPick }: { clinicId: string; date: string; onPick: (t: string) => void }) {
  const [slots, setSlots] = useState<string[] | null>(null);
  useEffect(() => {
    getSlots(clinicId, date).then((r) => setSlots(r.slots));
  }, [clinicId, date]);
  if (slots === null) return <ActivityIndicator />;
  return (
    <FlatList
      data={slots}
      keyExtractor={(t) => t}
      renderItem={({ item }) => (
        <Pressable onPress={() => onPick(item)}>
          <View>
            <Text>{item}</Text>
          </View>
        </Pressable>
      )}
    />
  );
}
