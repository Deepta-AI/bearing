import { Pressable, StyleSheet, Text, View } from 'react-native';

import type { ReturnReason } from './schemas';

const LABELS: Record<ReturnReason, string> = {
  damaged: 'Damaged',
  missing: 'Missing from the delivery',
  wrong_item: 'Wrong item',
  expired: 'Past its date',
};

type Props = { value: ReturnReason | null; onChange: (r: ReturnReason) => void };

/** The four return reasons as a single-choice list. */
export function ReturnReasonPicker({ value, onChange }: Props) {
  return (
    <View accessibilityRole="radiogroup" style={styles.group}>
      {(Object.keys(LABELS) as ReturnReason[]).map((r) => (
        <Pressable
          key={r}
          accessibilityRole="radio"
          accessibilityState={{ checked: value === r }}
          onPress={() => onChange(r)}
          style={[styles.option, value === r && styles.selected]}
        >
          <Text>{LABELS[r]}</Text>
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  group: { gap: 8 },
  option: { minHeight: 44, paddingHorizontal: 12, justifyContent: 'center', borderRadius: 8, borderWidth: 1, borderColor: '#c9ced6' },
  selected: { borderColor: '#1f6f43', borderWidth: 2 },
});
