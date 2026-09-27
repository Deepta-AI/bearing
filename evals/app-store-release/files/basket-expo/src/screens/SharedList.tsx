import { Text } from 'react-native';
import { flags } from '../flags';

export default function SharedList() {
  if (!flags.sharedLists) return null;
  return <Text>Invite your household</Text>;
}
