import { StyleSheet, Text, View } from 'react-native';

/** The shop front. Catalogue browsing ships in 2.4. */
export default function Shop() {
  return (
    <View style={styles.screen}>
      <Text style={styles.title}>Shop</Text>
      <Text>Browse the catalogue on basket.example.com while the app catalogue is built.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: 24, gap: 8 },
  title: { fontSize: 24, fontWeight: '700' },
});
