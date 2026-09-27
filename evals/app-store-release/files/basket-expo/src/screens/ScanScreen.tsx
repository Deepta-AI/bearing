import { CameraView, useCameraPermissions } from 'expo-camera';
import { Button, Text, View } from 'react-native';
import { addItemByBarcode } from '../lib/lists';
import { track } from '../lib/analytics';

export default function ScanScreen({ listId }: { listId: string }) {
  const [permission, requestPermission] = useCameraPermissions();

  if (!permission?.granted) {
    return (
      <View>
        <Text>Allow the camera to scan barcodes.</Text>
        <Button title="Allow camera" onPress={requestPermission} />
      </View>
    );
  }

  return (
    <CameraView
      style={{ flex: 1 }}
      barcodeScannerSettings={{ barcodeTypes: ['ean13', 'upc_a'] }}
      onBarcodeScanned={async ({ data }) => {
        await addItemByBarcode(listId, data);
        track('item_scanned');
      }}
    />
  );
}
